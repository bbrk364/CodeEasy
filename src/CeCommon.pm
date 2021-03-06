#!/usr/bin/perl -w 
################################################################################
# CodeEasy Customer Toolkit Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: This is a common Perl package which is included in the calling Perl
#          scripts vis the 'use <package>' constct
#          variables and sub-routines are called from other scripts as follows;
#              $my_variable   $CeCommon::VARIABLE
#              $my_subroutine $CeCommon::my_subroutine
#          
#
# Author:  Michael Johnson (michael.johnson@netapp.com)
#           
#
# NETAPP CONFIDENTIAL
# -------------------
# Copyright 2015 NetApp, Inc. All Rights Reserved.
#
# NOTICE: All information contained herein is, and remains the property
# of NetApp, Inc.  The intellectual and technical concepts contained
# herein are proprietary to NetApp, Inc. and its suppliers, if applicable,
# and may be covered by U.S. and Foreign Patents, patents in process, and are
# protected by trade secret or copyright law. Dissemination of this
# information or reproduction of this material is strictly forbidden unless
# permission is obtained from NetApp, Inc.
#
################################################################################

# declair this file (.pm) as a Perl package
package CeCommon;

use Env;           # package to allow reading UNIX environment vars
use Cwd;
use FindBin();     # The FindBin helps indentify the path this executable and thus its path
use strict;        # require strict programming rules
use warnings;


#---------------------------------------- 
# load NetApp manageability SDK APIs
#---------------------------------------- 
# SDK setenv not set, assume the SDK is in parallel to the CodeEasy
# tarball installation    ***** CUSTOMIZE ME *****
use lib "$FindBin::Bin/../../netapp-manageability-sdk-5.5/lib/perl/NetApp";
# use lib "<your_full_path>/netapp-manageability-sdk-5.5/lib/perl/NetApp";

# load the NetApp Manageability SDK components
use NaServer;      
use NaElement;  

#---------------------------------------- 
# load CodeEasy packages
#---------------------------------------- 
use lib "$FindBin::Bin/.";
use CeInit;                      # found in the file CeInit.pm

$main::cdot_version = "unknown"; # variable holder for cDOT version



###################################################################################
# Initialize filer - return data structure
###################################################################################
sub init_filer {

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    #--------------------------------------- 
    # initialize access to NetApp filer
    #--------------------------------------- 
    print "\nINFO  ($main::progname): Connecting to storage...\n" .
            "      Cluster: $CeInit::CE_CLUSTER\n" .
            "      Vserver: $CeInit::CE_VSERVER\n\n";

    # Creates a new object of NaServer class and sets the default value for the following object members:
    #   syntax: new($server, $majorversion, $minorversion)
    #           5.3.1 NMSDK use NaServer($host,1,7)
    # sets the name of the Storage cluster to which a Cluster API need to 
    # be tunneled from a Cluster Management Interface.
    print "INFO  ($main::progname): Initial connection to filer using ONTAPI version $CeInit::CE_ONTAPI_MAJOR_VERSION\.$CeInit::CE_ONTAPI_MINOR_VERSION\n";
    my $naserver = NaServer->new($CeInit::CE_CLUSTER, $CeInit::CE_ONTAPI_MAJOR_VERSION, $CeInit::CE_ONTAPI_MINOR_VERSION);

    # set vserver to access
    # this is the vserve name - NOT a DNS/IP Address of a LIF.  Its the textual name of the VServer.
    $naserver->set_vserver("$CeInit::CE_VSERVER");

    # set API transport type - HTTP is the default
    $naserver->set_transport_type($CeInit::CE_TRANSPORT_TYPE) if (defined $CeInit::CE_TRANSPORT_TYPE);

    # pass username/password for vserver ontapi application access
    #     $naserver->set_admin_user("vsadmin", "devops123");
    $naserver->set_admin_user(@CeInit::CE_ADMIN_USER);

    # set communication style - typically just 'LOGIN'
    $naserver->set_style($CeInit::CE_STYLE)                   if (defined $CeInit::CE_STYLE);

    # set communication port
    $naserver->set_port($CeInit::CE_PORT)                     if (defined $CeInit::CE_PORT);

    #--------------------------------------- 
    # check connection to the filer by requesting a simple ontapi version status
    #--------------------------------------- 
    my $api_call =  "system-get-version";
    $out =  $naserver->invoke($api_call);

    # check error status and exit if basic communication with the filer can't be estabilished.
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($main::progname): FAIL: Unable to connect to cluster/vserver: $CeInit::CE_CLUSTER/$CeInit::CE_VSERVER \n";
        print "ERROR ($main::progname): $api_call returned with $errno and reason: " . 
	                          '"' .  $out->results_reason() . "\n";
        print "ERROR ($main::progname): Exiting with error.\n";
        exit 1;
    }

    #--------------------------------------- 
    # print the controller version
    # Example:       NetApp Release 8.2.1RC2X6 Cluster-Mode: Wed Dec 18 19:14:04 PST 2013 
    #--------------------------------------- 
    $main::cdot_version = $out->child_get_string("version");
    print "INFO  ($main::progname): Storage Controller <$CeInit::CE_CLUSTER> is running ONTAP version:\n" . 
          "      $main::cdot_version\n\n";

    # check that filer is running cDOT and not 7-mode
    if ( $out->child_get_string("is-clustered") eq "true") {
	print "INFO  ($main::progname): Storage Controller <$CeInit::CE_CLUSTER> is running cDOT.\n\n";
    } else {
	print   "ERROR ($main::progname): Storage Controller <$CeInit::CE_CLUSTER> is running in 7-mode\n" .
	        "       These scripts support cDOT (Clustered Data OnTap) only\n" .
	        "Exiting...\n";
	exit 1;
    }

    #--------------------------------------- 
    # check connection to the filer by requesting a simple ontapi version status
    #--------------------------------------- 
    $api_call = "system-get-ontapi-version";
    $out =  $naserver->invoke("$api_call");

    # check error status and exit if basic communication with the filer can't be estabilished.
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($main::progname): FAIL: Unable to connect to cluster/vserver: $CeInit::CE_CLUSTER/$CeInit::CE_VSERVER \n";
        print "ERROR ($main::progname): $api_call returned with $errno and reason: " . 
	                          '"' .  $out->results_reason() . "\n";
        print "ERROR ($main::progname): Exiting with error.\n";
        exit 1;
    }

    $main::ontapi_major_version = $out->child_get_string("major-version");
    $main::ontapi_minor_version = $out->child_get_string("minor-version");
    print "INFO  ($main::progname): ONTAP API version ($api_call) $main::ontapi_major_version\.$main::ontapi_minor_version\n\n";
    print "INFO  ($main::progname): Reconnecting to filer using ONTAP API version $main::ontapi_major_version\.$main::ontapi_minor_version\n";


    # ---------------------------------------- 
    # call naserver again now with known API major/minor version 
    # which is known compatible with ONTAP version
    # ---------------------------------------- 
    $naserver = NaServer->new($CeInit::CE_CLUSTER, $main::ontapi_major_version, $main::ontapi_minor_version);
    
    # set vserver to access
    # this is the vserve name - NOT a DNS/IP Address of a LIF.  Its the textual name of the VServer.
    $naserver->set_vserver("$CeInit::CE_VSERVER");

    # set API transport type - HTTP is the default
    $naserver->set_transport_type($CeInit::CE_TRANSPORT_TYPE) if (defined $CeInit::CE_TRANSPORT_TYPE);

    # pass username/password for vserver ontapi application access
    #     $naserver->set_admin_user("vsadmin", "devops123");
    $naserver->set_admin_user(@CeInit::CE_ADMIN_USER);

    # set communication style - typically just 'LOGIN'
    $naserver->set_style($CeInit::CE_STYLE)                   if (defined $CeInit::CE_STYLE);

    # set communication port
    $naserver->set_port($CeInit::CE_PORT)                     if (defined $CeInit::CE_PORT);

    #--------------------------------------- 
    # check connection to the filer by requesting a simple ontapi version status
    #--------------------------------------- 
    $api_call =  "system-get-version";
    $out =  $naserver->invoke($api_call);

    # check error status and exit if basic communication with the filer can't be estabilished.
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($main::progname): FAIL: Unable to connect to cluster/vserver: $CeInit::CE_CLUSTER/$CeInit::CE_VSERVER \n";
        print "ERROR ($main::progname): $api_call returned with $errno and reason: " . 
	                          '"' .  $out->results_reason() . "\n";
        print "ERROR ($main::progname): Exiting with error.\n";
        exit 1;
    }



    # return to calling program
    return $naserver;

} # end of init_filer()


###################################################################################
# list current list of snapshots
###################################################################################   
sub list_snapshots {

    # pass vserver handle and current volume into the sub
    my ($naserver, $volume) = @_;

    my $snap_cnt      = 0;
    my $snap_skip_cnt = 0;

    #--------------------------------------- 
    # Get a list of the snapshots associated with the volume
    #--------------------------------------- 
    # vserver>  vol snapshot show -volume project_A_jenkin_build 
    my %snapshot_list = &CeCommon::getSnapshotList($naserver, $volume);

    print "\nINFO  ($main::progname): Snapshot list for volume '$volume'\n" .
            "      (NOTE: hourly, daily and weekly snapshots not listed)\n\n";
    printf("      %-40s     %-40s Snapshot Date\n", "Volume Name", "Snapshot Name");
    printf("      %-40s     %-40s --------------------\n", "--------------------", "--------------------");

    # loop thru list of snapshot directories 
    foreach my $snap (sort {$snapshot_list{$a} <=> $snapshot_list{$b}} keys %snapshot_list) {

	# skip regular snapshot - so only specifically named snapshots are shown
	if ( ($snap =~ /^hourly/) || ($snap =~ /^daily/) || ($snap =~ /^weekly/) ) {
	    print "skip...$snap\n" if (0);
	    $snap_skip_cnt++;
	    next;
	}

	# remaining snapshot
	my $formatted_snap_time = localtime($snapshot_list{$snap});
	#print "\t$volume $snap  $formatted_snap_time\n";
	printf("      %-40s     %-40s $formatted_snap_time\n", $volume, $snap );

	# keep track of snapshot count
	$snap_cnt++;
    }

    # report nice message if not snapshot directories found
    if ($snap_cnt == 0 ) {
	print "\n      No snapshots found for volume '$volume'\n";
	print   "      hourly/daily/weekly snapshots were found, but excluded\n\n" if ($snap_skip_cnt != 0);
    } else {
	print "\n      $snap_cnt snapshots found for volume '$volume'\n";
    }

    # exit program successfully
    print "\n$main::progname exited successfully.\n\n";
    exit 0;

} # end of sub &list_snapshots()


###################################################################################   
# Name: vGetcDOTList()
# Func: Note that Perl is a lot more forgiving with long object lists than ONTAP is.  As a result,
#	  we have the luxury of returning the entire set of objects back to the caller.  Get all the
#	  objects rather than waiting.
###################################################################################   
sub vGetcDOTList {
    my ( $zapiServer, $zapiCall, @optArray ) = @_;
    my @list;
    my $done = 0;
    my $tag  = 0;
    my $zapi_results;
    my $MAX_RECORDS = 255;

    # loop thru calling the command until all tags are processed
    while ( !$done ) {

	#print "Attempting to collect " . ( $tag ? "more " : "" ) . "API results for $zapiCall from vserver ...\n" if ($main::verbose);

	# if a tag exists, pass it to the zapi command
	if ( $tag ) {
	    if ( @optArray ) {
		$zapi_results = $zapiServer->invoke( $zapiCall, "tag", $tag, "max-records", $MAX_RECORDS, @optArray );
	    } else {
		$zapi_results = $zapiServer->invoke( $zapiCall, "tag", $tag, "max-records", $MAX_RECORDS );
	    }
	} else {
	    # not tag exists - probably the first time the command is called
	    if ( @optArray ) {
		$zapi_results = $zapiServer->invoke( $zapiCall, "max-records", $MAX_RECORDS, @optArray );
	    } else {
		$zapi_results = $zapiServer->invoke( $zapiCall, "max-records", $MAX_RECORDS );
	    }
	}

	# check status of the call
	if ( $zapi_results->results_status() eq "failed" ) {
	    print "ERROR: ONTAP API call $zapiCall failed: " . $zapi_results->results_reason() . "\n";
	    return( 0 );
	}

	# get next tag (if multiple queries are required to get large lists
	$tag = $zapi_results->child_get_string( "next-tag" );

	my $list_attrs = $zapi_results->child_get( "attributes-list" );
	if ( $list_attrs ) {
	    my @list_items = $list_attrs->children_get();
	    if ( @list_items ) {
		push( @list, @list_items );
	    }
	}

	# if no tags are left, then exit the while loop
	if ( !$tag ) {
	    $done = 1;
	}
    }

    # return list to calling sub
    return( @list );

} # end of sub vGetcDOTList()


###################################################################################   
# Name: getVolumeList()
# Func: return list of volumes on vserver
###################################################################################   
sub getVolumeList {

    # pass naserver handle into the sub
    my ($naserver) = @_;

    my %volume_list = ();

    # get list of volume data
    my @vlist = &CeCommon::vGetcDOTList( $naserver, "volume-get-iter" );

    # loop thru data and pull out attribute information
    print "DEBUG: List of volumes on the vserver\n" if ($main::verbose);
    foreach my $tattr ( @vlist ) {
	my $vol_id_attrs = $tattr->child_get( "volume-id-attributes" );
	my $vol_space_attrs = $tattr->child_get( "volume-space-attributes" );

	#print "DEBUG: volume-id-attributes\n";
	#printf($tattr->sprintf());
	
	# check that the ->child_get function returned data 
	if ( $vol_id_attrs ) {
	    my $volume_name = $vol_id_attrs->child_get_string( "name" );

            my $volume_size;
            if ( $vol_space_attrs ) {
                $volume_size = $vol_space_attrs->child_get_string( "size" );
            }

	    # store volume in list which is easy to access via hash
	    $volume_list{$volume_name} = $volume_size;

	    print "       $volume_name\n" if ($main::verbose);
	}
    }

    # return list of volumes
    return %volume_list;

} # end sub &getVolumeList()

###################################################################################   
# Name: getFlexCloneList()
# Func: return list of flex clone volumes on vserver
###################################################################################   
sub getFlexCloneList {

    # pass naserver handle into the sub
    my ($naserver) = @_;

    my %clone_list;

    # get list of FlexClone data
    my @vlist = &CeCommon::vGetcDOTList( $naserver, "volume-clone-get-iter" );

    # loop thru data and pull out attribute information
    print "DEBUG: List of FlexClones on the vserver\n" if ($main::verbose);
    foreach my $vol_data ( @vlist ) {

	    # get the clone name from the lookup
	    my $clone_name     = $vol_data->child_get_string( "volume" );

	    # store volume in list which is easy to access via hash
	    $clone_list{$clone_name} = 1;

	    print "       $clone_name  \n" if ($main::verbose);
    }

    # return list of volumes
    return %clone_list;

} # end sub &getFlexCloneList()

###################################################################################   
# Name: getSnapshotList(naserver, volume)
# Func: return list of snapshots on the volume
###################################################################################   
sub getSnapshotList {

    # pass naserver handle into the sub
    my ($naserver, $volume) = @_;

    my %snapshot_list;

    # get list of snapshot data
    my @slist = &CeCommon::vGetcDOTList( $naserver, "snapshot-get-iter" );

    # loop thru the list of returned snapshot data
    foreach my $snap_data (@slist) {
	# get the clone name from the lookup

	# a data structure is returned - get the volume name and the snapshot
	# name from the data structure.
	my $snap_volume = $snap_data->child_get_string("volume");
	my $snap_name   = $snap_data->child_get_string("name");
	my $access_time = $snap_data->child_get_string("access-time");

	# all volumes will be returned - only collect snapshots for the
	# specified volume
	if ("$snap_volume" eq "$volume" ) {
	    print "DEBUG: snapshot: $snap_volume => $snap_name\n" if (0);

	    # store volume in list which is easy to access via hash
	    $snapshot_list{$snap_name} = $access_time;
	}
    }

    # return list of volumes
    return %snapshot_list;

} # end sub &getSnapshotList()



# ALL PERL PACKAGES (.pm files) must end with '1;'  
# So don't remove...
1;



############################################################
# NaServer::new
############################################################
# Prototype
#   new($server, $majorversion, $minorversion)
#
# Description
#   Creates a new object of NaServer class and sets the default value for the following object members:
#
#   $user= root
#   $password= ""
#   $style= LOGIN
#   $port= 80
#   $transport_type= HTTP
#   $servertype= FILER
#
# You can overwrite the default values by using the set Core APIs.
