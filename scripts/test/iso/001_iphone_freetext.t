package Test;

#  scripts/test/iso/001_iphone.t - all iPhone tests
# Copyright (C) 2001-2012 OTRS AG, http://otrs.org/
# --
# $Id: iPhone.pm,v 1.68 2012/02/01 18:51:07 md Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.68 $) [1];

use strict;
use warnings;

use basetest;
my $phone = basetest::NewPhone();

# create a new ticket
my $TicketID = $phone->{TicketObject}->TicketCreate(
    Title        => 'My ticket created by Agent A',
    Queue        => 'Raw',
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'open',
    CustomerNo   => '123465',
    CustomerUser => 'customer@example.com',
    OwnerID      => 1,
    UserID       => 1,
);

$phone-> _GetScreenElements(    Screen=> "Phone", UserID =>1  ); ##
$phone-> _GetScreenElements(    Screen=> "Move" , UserID =>1  );
$phone-> _GetScreenElements(    Screen=> "Compose", TicketID => $TicketID, UserID =>1);

 $phone-> _TicketPhoneNew();
 $phone-> _TicketCommonActions();

$phone-> _GetComposeDefaults(
    TicketID => $TicketID
    );