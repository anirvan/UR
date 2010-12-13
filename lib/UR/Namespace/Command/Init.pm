package UR::Namespace::Command::Init;
use strict;
use warnings;
use UR;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => "Command",
    has => [
        namespace => {
            is => 'Text',
            shell_args_position => 1,
            doc => 'create this namespace'
        },
        db => {
            is => 'Text',
            is_optional => 1,
            shell_args_position => 2,
            doc => 'DBI connection string for the primary data source',
        },
    ],
    doc => 'initialize a new UR app in one command',
);

sub sub_command_sort_position { 1 }

sub execute {
    my $self = shift;
    my $c;

    $self->status_message("*** ur define namespace " . $self->namespace);
    UR::Namespace::Command::Define::Namespace->execute(nsname => $self->namespace) or return;

    $self->status_message("*** cd " . $self->namespace);
    chdir $self->namespace or ($self->error_message("error changing to namespace dir? $!") and return);
   
    $self->status_message("\n*** ur define db " . $self->db);
    $c = UR::Namespace::Command::Define::Db->create(uri => $self->db) or return;
    $c->dump_status_messages(1);
    $c->execute();

    $self->status_message("\n*** ur update classes");
    my $c = UR::Namespace::Command::Update::Classes->create();
    $c->dump_status_messages(1);
    $c->execute();
    
    return 1; 
}

1;

