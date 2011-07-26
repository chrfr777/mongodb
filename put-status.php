<?php
require_once 'AWSSDKforPHP/sdk.class.php';

#date_default_timezone_set('UTC');

$m = new Mongo();
$cw = new AmazonCloudWatch();

$db = $m->admin;
$local = $m->selectDB( "local");

$replset = $local->selectCollection( "system.replset");
$replica_set_conf = $replset->findOne();

$ismaster = $db->command(array('ismaster'=>true));
$server_status = $db->command(array('serverStatus'=>true));
$replica_set_status =  $db->command(array('replSetGetStatus'=>true));

if( isset( $server_status['repl']['arbiterOnly']) && $server_status['repl']['arbiterOnly']) {
	$state = 'arbiter';
} else if( $server_status['repl']['ismaster']) {
	$state = 'primary';
} else {
	$state = 'secondary';
}

switch( $state) {
	case 'primary':
		# here we do the replica set metrics
		add_replica_set_metrics( $cw, $ismaster, $server_status, $replica_set_status, $replica_set_conf);
	case 'secondary':
		# and the metrics for primary & secondary
		add_host_metrics( $cw, $ismaster, $server_status,
			get_lag( $server_status['host'], $replica_set_status));
		break;
	case 'arbiter':
		# for an arbiter we don't add metrics, the healthy is
		# implicity in the replica set metrics
}

function add_replica_set_metrics( $cw, $ismaster, $server_status, $set_status, $replica_set_conf) {
	$dimensions = array(
		array( 'Name' => 'ReplSet',
			'Value' => $server_status['repl']['setName'])
	);
	$timestamp = date( DATE_RFC822, $server_status['localTime']->sec);

	# set totals and assume all unhealthy
        $nr_hosts = $nr_unhealthy_hosts = count( $ismaster['hosts']);
        $nr_passives = $nr_unhealthy_passives =
                isset( $ismaster['passives']) && count( $ismaster['passives']) ?
                count( $ismaster['passives']) : 0;
        $nr_arbiters = $nr_unhealthy_arbiters = count( $ismaster['arbiters']);

        foreach( $set_status['members'] as $i => $member) {
		if( isset( $replica_set_conf['members'][$i]['priority']) &&
				$replica_set_conf['members'][$i]['priority'] == 0 ) {
			$nr_unhealthy_passives -= $member['health'];
		} else {
			if( $member['state'] == 1 or $member['state'] == 2) {
				# primary or secondary
				$nr_unhealthy_hosts -= $member['health'];
			} else if( $member['state'] == 7) {
				# arbiter
				$nr_unhealthy_arbiters -= $member['health'];
			}
		}
        }

	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'HealthyHostCount',
			'Dimensions' => $dimensions,
			'Value' => $nr_hosts - $nr_unhealthy_hosts,
			'Timestamp' => $timestamp,
			'Unit' => 'Count'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'UnHealthyHostCount',
			'Dimensions' => $dimensions,
			'Value' => $nr_unhealthy_hosts,
			'Timestamp' => $timestamp,
			'Unit' => 'Count'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'PassiveHostCount',
			'Dimensions' => $dimensions,
			'Value' => $nr_passives - $nr_unhealthy_passives,
			'Timestamp' => $timestamp,
			'Unit' => 'Count'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'UnHealthyPassiveHostCount',
			'Dimensions' => $dimensions,
			'Value' => $nr_unhealthy_passives,
			'Timestamp' => $timestamp,
			'Unit' => 'Count'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'ArbiterCount',
			'Dimensions' => $dimensions,
			'Value' => $nr_arbiters - $nr_unhealthy_arbiters,
			'Timestamp' => $timestamp,
			'Unit' => 'Count'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'UnHealthyArbiterCount',
			'Dimensions' => $dimensions,
			'Value' => $nr_unhealthy_arbiters,
			'Timestamp' => $timestamp,
			'Unit' => 'Count'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
}

function add_host_metrics( $cw, $ismaster, $server_status, $lag) {
	$state = $ismaster['ismaster'] ? 'primary' : 'secondary';
	$timestamp = date( DATE_RFC822, $server_status['localTime']->sec);

	$dimensions = array(
		array('Name' => 'Host', 'Value' => $server_status['host'])
	);
 
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'OperationsQueuedWaitingForLock',
			'Dimensions' => $dimensions,
			'Value' => $server_status['globalLock']['currentQueue']['total'],
			'Timestamp' => $timestamp,
			'Unit' => 'Count'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'ReadOperationsQueuedWaitingForLock',
			'Dimensions' => $dimensions,
			'Value' => $server_status['globalLock']['currentQueue']['readers'],
			'Timestamp' => $timestamp,
			'Unit' => 'Count'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'WriteOperationsQueuedWaitingForLock',
			'Dimensions' => $dimensions,
			'Value' => $server_status['globalLock']['currentQueue']['writers'],
			'Timestamp' => $timestamp,
			'Unit' => 'Count'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'ActiveClients',
			'Dimensions' => $dimensions,
			'Value' => $server_status['globalLock']['activeClients']['total'],
			'Timestamp' => $timestamp,
			'Unit' => 'Count'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'ActiveReaders',
			'Dimensions' => $dimensions,
			'Value' => $server_status['globalLock']['activeClients']['readers'],
			'Timestamp' => $timestamp,
			'Unit' => 'Count'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'ActiveWriters',
			'Dimensions' => $dimensions,
			'Value' => $server_status['globalLock']['activeClients']['writers'],
			'Timestamp' => $timestamp,
			'Unit' => 'Count'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'ResidentMemory',
			'Dimensions' => $dimensions,
			'Value' => $server_status['mem']['resident'],
			'Timestamp' => $timestamp,
			'Unit' => 'Megabytes'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'VirtualMemory',
			'Dimensions' => $dimensions,
			'Value' => $server_status['mem']['virtual'],
			'Timestamp' => $timestamp,
			'Unit' => 'Megabytes'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'MappedMemory',
			'Dimensions' => $dimensions,
			'Value' => $server_status['mem']['mapped'],
			'Timestamp' => $timestamp,
			'Unit' => 'Megabytes'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'ActiveConnections',
			'Dimensions' => $dimensions,
			'Value' => $server_status['connections']['current'],
			'Timestamp' => $timestamp,
			'Unit' => 'Count'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'LastFlushOperation',
			'Dimensions' => $dimensions,
			'Value' => $server_status['backgroundFlushing']['last_ms'],
			'Timestamp' => $timestamp,
			'Unit' => 'Microseconds'
		),
	));
	if( !$response->isOK()) { print_r( $response); }
	$response = $cw->put_metric_data('9Apps/MongoDB', array(
		array(
			'MetricName' => 'OpenCursors',
			'Dimensions' => $dimensions,
			'Value' => $server_status['cursors']['totalOpen'],
			'Timestamp' => $timestamp,
			'Unit' => 'Count'
		),
	));
	if( !$response->isOK()) { print_r( $response); }

	# add lag if secondary
	if( !$ismaster['ismaster']) {
		$response = $cw->put_metric_data('9Apps/MongoDB', array(
			array(
				'MetricName' => 'Lag',
				'Dimensions' => $dimensions,
				'Value' => $lag,
				'Timestamp' => $timestamp,
				'Unit' => 'Seconds'
			),
		));
	}
	if( !$response->isOK()) { print_r( $response); }
}

# return lag of host, relative to master
function get_lag( $host, $replica_set_status) {
	foreach( $replica_set_status['members'] as $member) {
		if( $member['state'] == 1) {
			$base = $member['optime']->sec;
		}

		if( strpos( $member['name'], $host) !== false) {
			$me = $member['optime']->sec;
		}

		# we are done when we are done
		if( isset( $base) && isset( $me)) break;
	}

	return $me - $base;
}

?>
