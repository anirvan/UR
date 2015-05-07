
package UR::ModuleLoader;

use strict;
use warnings;
require UR;
our $VERSION = "0.43"; # UR $VERSION;

Class::Autouse->autouse(\&dynamically_load_class);
Class::Autouse->sugar(\&define_class);

our @CARP_NOT = qw(Class::Autouse);

sub define_class {
    my ($class,$func,@params) = @_;
    return unless $UR::initialized;
    return unless $Class::Autouse::ORIGINAL_CAN->("UR::Object::Type","get");

    # Handle the special case of defining a new class
    # This lets us have the effect of a UNIVERSAL::class method, w/o mucking with UNIVERSAL
    if (defined($func) and $func eq "class" and @params > 1 and $class ne "UR::Object::Type") {
        my @class_params;
        if (@params == 2 and ref($params[1]) eq 'HASH') {
            @class_params = %{ $params[1] };
        }
        elsif (@params == 2 and ref($params[1]) eq 'ARRAY') {
            @class_params = @{ $params[1] };
        }
        else {
            @class_params = @params[1..$#params];
        }
        my $class_meta = UR::Object::Type->define(class_name => $class, @class_params);
        unless ($class_meta) {
            Carp::croak "error defining class $class!";
        }
        return sub { $class };
    }

    else {
        return;
    }
}

sub _should_dynamically_load_package {
    my $package = shift;
    # Don't even try to load unless we're done boostrapping somewhat.
    return unless $UR::initialized;
    return unless $Class::Autouse::ORIGINAL_CAN->("UR::Object::Type","get");

    # Some modules (Class::DBI, recently) call UNIVERSAL::can directly with things which don't even resemble
    # class names.  Skip doing any work on anything which isn't at least a two-part class name.
    # We refuse explicitly to handle top-level namespaces below anyway, and this will keep us from 
    # slowing down other modules just to fail late.

    my ($namespace) = ($package =~ /^(.*?)::/);
    return unless $namespace;

    unless ($namespace->isa("UR::Namespace")) {
        return;
    }

    unless ($namespace->should_dynamically_load_class($package)) {
        return;
    }

    return $namespace;
}

our %loading;

sub dynamically_load_class {
    my ($class,$func,@params) = @_;

    return unless my $namespace = _should_dynamically_load_package($class);

    if (defined($func) and $func eq "class" and @params > 1 and $class ne "UR::Object::Type") {
        # a "class" statement caught by the above define_class call
        return;
    }

    return if $loading{$class};
    local %loading = ( %loading, class => 1 );

    # Attempt to get a class object, loading it as necessary (probably).
    # TODO: this is a non-standard accessor
    my $meta = $namespace->get_member_class($class);
    unless ($meta) {
        return;
    }

    # Handle the case in which the class is not "generated".
    # These are generated by default when used, so this is a corner case.
    unless ($meta->generated())
    {
        # we have a new class
        # attempt to auto-generate it
        unless ($meta->generate)
        {
            Carp::confess("failed to auto-generate $class");
        }
    }

    # Return a descriptive error message for the caller.
    my $fref;
    if (defined $func) {
        $fref = $class->can($func);
        unless ($fref) {
            Carp::confess("$class was auto-generated successfully but cannot find method $func");
        }
        return $fref;
    }

    return 1;
};

1;


=pod

=head1 NAME

UR::ModuleLoader - UR hooks into Class::Autouse

=head1 DESCRIPTION

UR uses Class::Autouse to handle automagic loading for modules.  As long
as some part of an application "use"s a Namespace module, the autoloader
will handle loading modules under that namespace when they are needed.

=head1 SEE ALSO

UR, UR::Namespace

=cut
