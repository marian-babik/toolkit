#!/usr/bin/perl -w
# This test verifies the output of the get_services method

use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use lib "$Bin/../lib";
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( {level => 'OFF'} );

use Test::More tests => 12;

use Config::General;
use Data::Dumper;
use Test::MockObject::Extends;

use perfSONAR_PS::NPToolkit::DataService::Host;
use perfSONAR_PS::NPToolkit::UnitTests::Util qw( test_result );
use perfSONAR_PS::NPToolkit::UnitTests::Mock qw( succeed_value array_value );

my $basedir = 't';
my $config_file = $basedir . '/etc/web_admin.conf';
my $ls_file = $basedir . '/etc/lsregistrationdaemon.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
my %conf = $conf_obj->getall;

my $bwctl_config = 't/etc/bwctl-server.conf';
my $bwctl_limits = 't/etc/bwctl-server.limits';

my $owamp_config = 't/etc/owamp-server.conf';
my $owamp_limits = 't/etc/owamp-server.limits';

my $data;
my $params = {};
$params->{'config_file'} = $config_file;
$params->{'load_ls_registration'} = 1;
$params->{'ls_config_file'} = $ls_file;

$params->{'bwctl_config'} = $bwctl_config;
$params->{'bwctl_limits'} = $bwctl_limits;

$params->{'owamp_config'} = $owamp_config;
$params->{'owamp_limits'} = $owamp_limits;

# check the services
# we want to check these 4 conditions
# each service enabled/disabled, each service running/stopped
my $qmock = Test::MockObject->new();
my @service_running_vals = ( 0, 1 );
my @service_enabled_vals = ( 0, 1 );
my $package_version = '1.2.3.4';

my @fake_interfaces = (
    'fake-ps-node.domain.edu',
    'localhost'
);

# Mock the "package_version" method
# This allows us to set tit he package version to whatever we want for testing.

$qmock->fake_module(
    'perfSONAR_PS::NPToolkit::Services::Base',
    package_version => sub{ perfSONAR_PS::NPToolkit::UnitTests::Mock::succeed_value( $package_version ) }
);

# Mock the "lookup_interfaces" method

$qmock->fake_module(
    'perfSONAR_PS::NPToolkit::Services::NetworkBase',
    lookup_interfaces => sub{ perfSONAR_PS::NPToolkit::UnitTests::Mock::array_value( @fake_interfaces ) }
);

foreach my $running ( @service_running_vals ) {
    foreach my $enabled (@service_enabled_vals) {
        my $expected_services = get_expected_services( $running, $enabled, $package_version );

        # Mock the 'check_running' method
        $qmock->fake_module(
            'perfSONAR_PS::NPToolkit::Services::Base',
            check_running => sub{ perfSONAR_PS::NPToolkit::UnitTests::Mock::succeed_value( $running ) }
#            disabled => sub{ perfSONAR_PS::NPToolkit::UnitTests::Mock::succeed_value( ! $enabled ) }
        );

        # Mock the 'disabled' method
        $qmock->fake_module(
            'perfSONAR_PS::NPToolkit::Services::Base',
            disabled => sub{ perfSONAR_PS::NPToolkit::UnitTests::Mock::succeed_value( !$enabled ) }
        );

        my $info = perfSONAR_PS::NPToolkit::DataService::Host->new( $params );

        my $services_info = $info->get_services();


        test_result($services_info, $expected_services, "Services info is as expected");

    }

}

sub get_expected_services {
    my ($running_int, $enabled, $version) = @_;
    my $running = ( $running_int > 0 ? 'yes' : 'no' );

    $running = "disabled" if ( !$enabled && !$running_int );

    my $esmond_addresses = [];
    my $pscheduler_addresses = [];

    foreach my $addr ( @fake_interfaces ) {
        push @$esmond_addresses, 'https://' . $addr . '/esmond/perfsonar/archive/';
        push @$pscheduler_addresses, 'https://' . $addr . '/pscheduler';
    }

    my $expected_services = {
        'services' => [
            {
                'is_running' => $running,
                'addresses' => [],
                'version' => $version,
                'name' => 'bwctl',
                'daemon_port' => 4823,
                'testing_ports' => [
                    {
                        'min_port' => '6001',
                        'type' => 'peer',
                        'max_port' => '6200'
                    },
                    {
                        'min_port' => '5001',
                        'type' => 'iperf',
                        'max_port' => '5302'
                    },
                    {
                        'min_port' => '5301',
                        'type' => 'nuttcp',
                        'max_port' => '5602'
                    },
                    {
                        'min_port' => '5601',
                        'type' => 'owamp',
                        'max_port' => '5902'
                    },
                    {
                        'min_port' => '7001',
                        'type' => 'test',
                        'max_port' => '7900'
                    }
                ],
                'enabled' => $enabled
            },
            {
                'is_running' => $running,
                'addresses' => $esmond_addresses,
                'version' => $version,
                'name' => 'esmond',
                'enabled' => $enabled
            },
            {
                'is_running' => $running,
                'addresses' => [],
                'version' => $version,
                'name' => 'lsregistration',
                'enabled' => $enabled
            },
            {
                'is_running' => $running,
                'addresses' => [],
                'version' => $version,
                'name' => 'meshconfig-agent',
                'enabled' => $enabled
            },
            {
                'is_running' => $running,
                'addresses' => [],
                'version' => $version,
                'name' => 'owamp',
                'daemon_port' => 861,
                'testing_ports' => [
                    {
                        'min_port' => '9760',
                        'type' => 'test',
                        'max_port' => '10960'
                    }
                ],
                'enabled' => $enabled
            },
            {
                'is_running' => $running,
                'addresses' => $pscheduler_addresses,
                'version' => $version,
                'name' => 'pscheduler',
                'enabled' => $enabled
            }
        ]
    };

    return $expected_services;

}
