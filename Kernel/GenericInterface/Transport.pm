# --
# Kernel/GenericInterface/Transport.pm - GenericInterface network transport interface
# Copyright (C) 2001-2011 OTRS AG, http://otrs.org/
# --
# $Id: Transport.pm,v 1.4 2011/02/08 15:58:41 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::GenericInterface::Transport;

use strict;
use warnings;

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.4 $) [1];

=head1 NAME

Kernel::GenericInterface::Transport

=head1 SYNOPSIS

GenericInterface network transport interface.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object.

    use Kernel::Config;
    use Kernel::System::Encode;
    use Kernel::System::Log;
    use Kernel::System::Time;
    use Kernel::System::Main;
    use Kernel::System::DB;
    use Kernel::GenericInterface::Debugger;
    use Kernel::GenericInterface::Transport;

    my $ConfigObject = Kernel::Config->new();
    my $EncodeObject = Kernel::System::Encode->new(
        ConfigObject => $ConfigObject,
    );
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
    );
    my $TimeObject = Kernel::System::Time->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $DebuggerObject = Kernel::GenericInterface::Debugger->new(
        ConfigObject   => $ConfigObject,
        EncodeObject   => $EncodeObject,
        LogObject      => $LogObject,
        MainObject     => $MainObject,
        DebuggerObject => $DebuggerObject,
    );
    my $TransportObject = Kernel::GenericInterface::Transport->new(
        ConfigObject  => $ConfigObject,
        LogObject     => $LogObject,
        DBObject      => $DBObject,
        MainObject    => $MainObject,
        TimeObject    => $TimeObject,
        EncodeObject  => $EncodeObject,

        WebRequest    => CGI::Fast->new(), # optional, e. g. if fast cgi is used, the CGI object is already provided

        TransportConfig => {
            Type => 'HTTP::SOAP',
            Config => {
                ...
            },
        },
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    for my $Needed (
        qw(MainObject ConfigObject LogObject EncodeObject TimeObject DBObject DebuggerObject TransportConfig)
        )
    {
        $Self->{$Needed} = $Param{$Needed} || return { ErrorMessage => "Got no $Needed!" };
    }

    # select and instantiate the backend
    my $Backend = 'Kernel::GenericInterface::Transport::' . $Self->{TransportConfig}->{Type};
    $Self->{MainObject}->Require($Backend)
        || return { ErrorMessage => "Backend $Backend not found." };
    $Self->{BackendObject} = $Backend->new(%$Self);

    # if the backend constructor failed, it returns an error hash, pass it on in this casd
    return $Self->{BackendObject} if ref $Self->{BackendObject} ne $Backend;

    return $Self;
}

=item ProviderProcessRequest()

process an incoming web service request. This function has to read the request data
from from the web server process.

    my $Result = $TransportObject->ProviderProcessRequest();

    $Result = {
        Success         => 1,                   # 0 or 1
        ErrorMessage    => '',                  # in case of error
        Operation       => 'DesiredOperation',  # name of the operation to perform
        Data            => {                    # data payload of request
            ...
        },
    };

=cut

sub ProviderProcessRequest {
    my ( $Self, %Param ) = @_;

    return $Self->{BackendObject}->RequesterPerformRequest(%Param);
}

=item ProviderGenerateResponse()

generate response for an incoming web service request.

    my $Result = $TransportObject->ProviderGenerateResponse(
        Success         => 1,       # 1 or 0
        ErrorMessage    => '',      # in case of an error
        Data            => {        # data payload for response
            ...
        },

    );

    $Result = {
        Success         => 1,                   # 0 or 1
        ErrorMessage    => '',                  # in case of error
        Response        => $Response,           # complete response
    };

=cut

sub ProviderGenerateResponse {
    my ( $Self, %Param ) = @_;

    return $Self->{BackendObject}->RequesterPerformRequest(%Param);
}

=item RequesterPerformRequest()

generate an outgoing web service request, receive the response and return its data..

    my $Result = $TransportObject->RequesterPerformRequest(
        Operation       => 'remote_op', # name of remote operation to perform
        Data            => {            # data payload for request
            ...
        },
    );

    $Result = {
        Success         => 1,                   # 0 or 1
        ErrorMessage    => '',                  # in case of error
        Data            => {
            ...
        },
    };

=cut

sub RequesterPerformRequest {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Operation Data)) {
        if ( !$Param{$Needed} ) {
            $Self->{DebuggerObject}->DebugLog(
                DebugLevel => 'error',
                Title      => "Got no $Needed!",
                Data =>
                    "Missing parameter $Needed in Kernel::GenericInterface::Transport::RequesterPerformRequest()",
            );

            return {
                ErrorMessage => "Got no $Needed!",
            };
        }
    }

    return $Self->{BackendObject}->RequesterPerformRequest(%Param);
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut

=head1 VERSION

$Revision: 1.4 $ $Date: 2011/02/08 15:58:41 $

=cut