package Zabbix7::API::Event;

use strict;
use warnings;
use 5.010;
use Carp;
use autodie;
use utf8;

use Moo;
extends qw/Exporter Zabbix7::API::CRUDE/;

use constant {
    EVENT_VALUE_OK      => 0,
    EVENT_VALUE_PROBLEM => 1,

    # Severities (same numeric values as trigger priorities in Zabbix 7.0)
    EVENT_SEVERITY_NOT_CLASSIFIED => 0,
    EVENT_SEVERITY_INFO           => 1,
    EVENT_SEVERITY_WARN           => 2,
    EVENT_SEVERITY_AVERAGE        => 3,
    EVENT_SEVERITY_HIGH           => 4,
    EVENT_SEVERITY_DISASTER       => 5,

    # Object type (most common = trigger)
    EVENT_OBJECT_TRIGGER  => 0,
    EVENT_OBJECT_DHOST    => 1,   # discovered host
    EVENT_OBJECT_DSERVICE => 2,
    EVENT_OBJECT_AUTOREG  => 3,
    EVENT_OBJECT_ITEM     => 4,   # internal item events
    EVENT_OBJECT_LLDRULE  => 5,
};

our @EXPORT_OK = qw/
    EVENT_VALUE_OK
    EVENT_VALUE_PROBLEM
    EVENT_SEVERITY_NOT_CLASSIFIED
    EVENT_SEVERITY_INFO
    EVENT_SEVERITY_WARN
    EVENT_SEVERITY_AVERAGE
    EVENT_SEVERITY_HIGH
    EVENT_SEVERITY_DISASTER
    EVENT_OBJECT_TRIGGER
    EVENT_OBJECT_DHOST
    EVENT_OBJECT_DSERVICE
    EVENT_OBJECT_AUTOREG
    EVENT_OBJECT_ITEM
    EVENT_OBJECT_LLDRULE
/;

our %EXPORT_TAGS = (
    value_types => [qw/
        EVENT_VALUE_OK
        EVENT_VALUE_PROBLEM
    /],
    severity_types => [qw/
        EVENT_SEVERITY_NOT_CLASSIFIED
        EVENT_SEVERITY_INFO
        EVENT_SEVERITY_WARN
        EVENT_SEVERITY_AVERAGE
        EVENT_SEVERITY_HIGH
        EVENT_SEVERITY_DISASTER
    /],
    object_types => [qw/
        EVENT_OBJECT_TRIGGER
        EVENT_OBJECT_DHOST
        EVENT_OBJECT_DSERVICE
        EVENT_OBJECT_AUTOREG
        EVENT_OBJECT_ITEM
        EVENT_OBJECT_LLDRULE
    /],
);

sub _readonly_properties {
    return {
        eventid     => 1,
        clock       => 1,
        ns          => 1,
        value       => 1,
        object      => 1,
        objectid    => 1,
        acknowledged=> 1,
        r_eventid   => 1,       # recovery event id (if closed)
        severity    => 1,       # only when suppressed=0 or selectSuppressionData used
        suppressed  => 1,
    };
}

sub id {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->data->{eventid} = $value;
        Log::Any->get_logger->debug("Set eventid: $value for event");
        return $self->data->{eventid};
    }
    my $id = $self->data->{eventid};
    Log::Any->get_logger->debug("Retrieved eventid: " . ($id // 'none'));
    return $id;
}

sub _prefix {
    my (undef, $suffix) = @_;
    return 'event' . ($suffix // '');
}

sub _extension {
    return (
        output             => 'extend',
        selectAcknowledges => 'extend',          # who/when acknowledged
        selectTags        => 'extend',            # event tags
        selectSuppressionData => 'extend',       # maintenance/downtime info
        selectRelatedObject => ['triggerid', 'description', 'priority', 'value'],  # ← most useful
        selectHosts        => ['hostid', 'host'],
    );
}


# Optional: helper for most common use-case
sub is_problem {
    my $self = shift;
    return $self->data->{value} && $self->data->{value} == EVENT_VALUE_PROBLEM;
}

sub is_acknowledged {
    my $self = shift;
    return $self->data->{acknowledged} ? 1 : 0;
}

1;
__END__

=pod

=head1 NAME

Zabbix7::API::Event -- Zabbix event objects (problems & OK events)

=head1 SYNOPSIS

  use Zabbix7::API::Event;

  # Get recent unacknowledged problems
  my $problems = $zabbix->fetch(
      'Event',
      params => {
          output             => 'extend',
          selectRelatedObject => ['description','priority','value'],
          selectHosts        => ['host'],
          value              => 1,               # PROBLEM
          acknowledged       => 0,
          sortfield          => 'clock',
          sortorder          => 'DESC',
          limit              => 50,
      }
  );

  foreach my $event (@$problems) {
      printf "%s - %s (sev %d) - %s\n",
          scalar localtime $event->data->{clock},
          $event->name,
          $event->data->{severity} // '?',
          $event->data->{hosts}[0]{host} // '-';
  }

  # Single event
  my $event = $zabbix->fetch_single('Event', params => { eventids => 123456 });

=head1 DESCRIPTION

Handles retrieval of Zabbix **events** (mostly problem and recovery events).

This is a subclass of C<Zabbix7::API::CRUDE>.

=head1 SEE ALSO

L<Zabbix7::API::CRUDE>,
Zabbix API documentation - event.get / event object

=head1 AUTHOR

SCOTTH

=head1 COPYRIGHT AND LICENSE

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2025 ScottH

This library is free software; you can redistribute it and/or modify it under
the terms of the GPLv3.

=cut