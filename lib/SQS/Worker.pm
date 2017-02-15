# ABSTRACT: manages workers reading from an SQS queue
package SQS::Worker;
use Paws;
use Moose::Role;
use Data::Dumper;
use SQS::Consumers::Default;

our $VERSION = '0.03';

requires 'process_message';

has queue_url => (is => 'ro', isa => 'Str', required => 1);
has region => (is => 'ro', isa => 'Str', required => 1);

has sqs => (is => 'ro', isa => 'Paws::SQS', lazy => 1, default => sub {
    my $self = shift;
    Paws->service('SQS', region => $self->region);
});

has log => (is => 'ro', required => 1);

has on_failure => (is => 'ro', isa => 'CodeRef', default => sub {
    return sub {
        my ($self, $message) = @_;
        $self->log->error("Error processing message " . $message->ReceiptHandle);
        $self->log->debug("Message Dump " . Dumper($message));
    }
});

has processor => (is => 'ro', lazy => 1, default => sub {
    my $self = shift;
    return SQS::Consumers::Default->new;
});

sub fetch_message {
    my $self = shift;
    $self->processor->fetch_message($self);
}

sub run {
    my $self = shift;
    while (1) {
        $self->fetch_message;
    }
}

sub delete_message {
    my ($self, $message) = @_;
    $self->sqs->DeleteMessage(
        QueueUrl      => $self->queue_url,
        ReceiptHandle => $message->ReceiptHandle,
    );
}

sub receive_message {
    my $self = shift;
    my $message_pack = $self->sqs->ReceiveMessage(
        WaitTimeSeconds => 20,
        QueueUrl => $self->queue_url,
        MaxNumberOfMessages => 1
    );
    return $message_pack;
}

1;
