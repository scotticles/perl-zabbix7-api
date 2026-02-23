package Zabbix7::API::Problem;

use strict;
use warnings;
use 5.010;
use Carp;
use Log::Any;

use Moo;
extends 'Zabbix7::API::CRUDE';

# Problems are identified by eventid (not problemid — that's internal/old naming)
sub id {
    my ($self, $value) = @_;
    if (defined $value) {
        $self->data->{eventid} = $value;
        Log::Any->get_logger->debug("Set eventid: $value for problem");
        return $self->data->{eventid};
    }
    my $id = $self->data->{eventid};
    Log::Any->get_logger->debug("Retrieved eventid for problem: " . ($id // 'none'));
    return $id;
}

# Most fields from problem.get are read-only.
# The few writable ones (acknowledged, severity in some cases via acknowledge call)
# are handled via special methods, not direct update.
sub _readonly_properties {
    return {
        eventid        => 1,
        source         => 1,
        object         => 1,
        objectid       => 1,
        clock          => 1,
        ns             => 1,
        r_eventid      => 1,
        r_clock        => 1,
        r_ns           => 1,
        cause_eventid  => 1,
        correlationid  => 1,
        userid         => 1,
        name           => 1,
        acknowledged   => 1,   # can be changed indirectly
        severity       => 1,   # can be changed indirectly
        suppressed     => 1,
        opdataid       => 1,
        urls           => 1,
        # tags, expression, etc. — depending on select*
    };
}

sub _prefix {
    my (undef, $suffix) = @_;
    return 'problem' . ($suffix // '');
}

# Default parameters useful for most problem.get calls
sub _extension {
    return (
        output      => 'extend',
        #selectHosts => ['hostid', 'host', 'name', 'dns', 'ip'],  # useful defaults
        selectTags  => 'extend',                                 # often wanted
        # selectAcknowledges => 'extend',                       # if needed
        # selectSuppressionData => 1,
    );
}

sub name {
    my $self = shift;
    my $name = $self->data->{name} // 'Unnamed problem';
    Log::Any->get_logger->debug("Retrieved problem name for eventid: "
        . ($self->id // 'new') . ": $name");
    return $name;
}

# Optional: helper for acknowledging a problem (calls event.acknowledge)
sub acknowledge {
    my ($self, %params) = @_;
    my $eventid = $self->id or croak "Cannot acknowledge without eventid";

    my $result = $self->_api->call('event.acknowledge', {
        eventids   => [$eventid],
        action     => 1,               # default: acknowledge
        message    => $params{message} // 'Acknowledged via API',
        severity   => $params{severity},  # optional new severity
        # suppress_until, etc.
    });

    # Refresh object data if successful
    if ($result && $result->{eventids}) {
        $self->refresh;
    }

    return $result;
}

1;

__END__

=pod

=head1 NAME

Zabbix7::API::Problem -- Zabbix problem/event objects (read-mostly)

=head1 SYNOPSIS

  # Fetch active problems (example)
  my @problems = $zabbix->fetch('Problem',
      params => {
          recent    => JSON::false,               # unresolved only
          filter    => { severity => [3,4,5,6] },  # >= Warning
          search    => { name => 'loss' },
      }
  );

  foreach my $prob (@problems) {
      printf "Problem: %s on hosts: %s\n",
          $prob->name,
          join(", ", map { $_->{host} } @{ $prob->data->{hosts} || [] });
  }

  # Acknowledge one
  $problems[0]->acknowledge(message => "Investigating");

=head1 DESCRIPTION

Read-oriented wrapper for Zabbix problems (from problem.get).

Problems are **read-only** in nature:
- No create
- No direct update
- Acknowledgement / severity changes go through event.acknowledge

This class disables create/update and provides convenience methods.

See L<Zabbix7::API::CRUDE> for inherited methods (fetch, get, etc.).

=head1 SEE ALSO

L<Zabbix API problem.get|https://www.zabbix.com/documentation/current/en/manual/api/reference/problem/get>,
L<Zabbix7::API::CRUDE>.

=head1 AUTHOR

SCOTTH

=head1 COPYRIGHT AND LICENSE

Same as the rest of Zabbix7::API distribution (GPLv3 or similar).

=cut