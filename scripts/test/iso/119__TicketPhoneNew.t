package Test_TicketPhoneNew;

#  scripts/test/iso/119__TicketPhoneNew.t - all iPhone tests
# Copyright (C) 2001-2012 OTRS AG, http://otrs.org/
# --
# $Id: 119__TicketPhoneNew.t,v 1.68 2012/02/01 18:51:07 md Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.68 $) [1];

use strict;
use warnings;
use YAML;
use basetest;
my $phone = basetest::NewPhone();
my %param = basetest::NewParam("_TicketPhoneNew");

my %UserList = $phone->{CustomerUserObject}->CustomerSearch(
    PostMasterSearch => "md\@otrs.com",
    );

my $UserID;
my $UserRand = "testuser123";
if (%UserList)
{
    warn Dump(\%UserList);
    my @ids = keys %UserList;
    $UserID = shift @ids;
} elsif(!%UserList) {
    
    my $Key = "test";
    $UserID = $phone->{CustomerUserObject}->CustomerUserAdd(
	Source         => 'CustomerUser',
	UserFirstname  => 'Firstname Test' . $Key,
	UserLastname   => 'Lastname Test' . $Key,
	UserCustomerID => $UserRand . '-Customer-Id',
	UserLogin      => $UserRand,
	UserEmail      => "md\@otrs.com",
	UserPassword   => 'some_pass',
	ValidID        => 1,
	UserID         => 1,
	);
}

warn "UserID $UserID";

#$param{CustomerID}=$UserID;
$param{CustomerUserLogin}=$UserRand . '-Email@example.com';
$param{StateID}=1;
$param{PriorityID}=1;

my $ret=$phone->_TicketPhoneNew(%param);
;
warn Dump($ret);
