package Test_GetNoteTypes;

#  scripts/test/iso/105__GetNoteTypes.t - all iPhone tests
# Copyright (C) 2001-2012 OTRS AG, http://otrs.org/
# --
# $Id: 105__GetNoteTypes.t,v 1.68 2012/02/01 18:51:07 md Exp $
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
my %param = basetest::NewParam("_GetNoteTypes");

$phone->{Config} = $phone->{ConfigObject}->Get('iPhone::Frontend::AgentTicketPhone');
my $ret=$phone->_GetNoteTypes(%param);

warn Dump($ret);
