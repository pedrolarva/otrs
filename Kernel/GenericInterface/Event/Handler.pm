# --
# Kernel/GenericInterface/Event/Handler.pm - event handler module for the GenericInterface
# Copyright (C) 2001-2011 OTRS AG, http://otrs.org/
# --
# $Id: Handler.pm,v 1.3 2011/02/28 10:02:24 mg Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::GenericInterface::Event::Handler;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.3 $) [1];

use Kernel::System::GenericInterface::Webservice;
use Kernel::System::VariableCheck qw(IsHashRefWithData);

use Kernel::Scheduler;
use Kernel::GenericInterface::Requester;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    for (
        qw(ConfigObject TicketObject LogObject UserObject CustomerUserObject SendmailObject DBObject MainObject EncodeObject TimeObject ValidObject)
        )
    {
        $Self->{$_} = $Param{$_} || die "Got no $_!";
    }

    $Self->{WebserviceObject} = Kernel::System::GenericInterface::Webservice->new(%$Self);

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data Event Config)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my %WebserviceList = %{
        $Self->{WebserviceObject}->WebserviceList(
            Valid => 1,
        ),
        };

    # loop over webservices
    WEBSERVICE:
    for my $WebserviceID ( sort keys %WebserviceList ) {

        my $WebserviceData = $Self->{WebserviceObject}->WebserviceGet(
            ID => $WebserviceID,
        );

        next WEBSERVICE if ( !IsHashRefWithData( $WebserviceData->{Config} ) );
        next WEBSERVICE if ( !IsHashRefWithData( $WebserviceData->{Config}->{Requester} ) );
        next WEBSERVICE
            if ( !IsHashRefWithData( $WebserviceData->{Config}->{Requester}->{Invoker} ) );

        # check invokers of the webservice, to see if some might be connected to this event
        INVOKER:
        for my $Invoker ( sort keys %{ $WebserviceData->{Config}->{Requester}->{Invoker} } ) {
            my $InvokerConfig = $WebserviceData->{Config}->{Requester}->{Invoker}->{$Invoker};

            next INVOKER if ( ref $InvokerConfig->{Events} ne 'ARRAY' );

            EVENT:
            for my $Event ( @{ $InvokerConfig->{Events} } ) {

                next EVENT if ref $Event ne 'HASH';

                # check if the invoker is connected to this event
                if ( $Event->{Event} eq $Param{Event} ) {

                    # create a scheduler task for later execution
                    if ( $Event->{Asynchronous} ) {
                        my $SchedulerObject = Kernel::Scheduler->new( %{$Self} );

                        my $TaskID = $SchedulerObject->TaskRegister(
                            Type => 'GenericInterface',
                            Data => {
                                WebserviceID => $WebserviceID,
                                Invoker      => $Invoker,
                                Data         => $Param{Data},
                            },
                        );

                    }
                    else {    # or execute Event directly
                        my $RequesterObject = Kernel::GenericInterface::Requester->new( %{$Self} );

                        $RequesterObject->Run(
                            WebserviceID => $WebserviceID,
                            Invoker      => $Invoker,
                            Data         => $Param{Data},
                        );
                    }
                }
            }
        }
    }

    return 1;
}

1;
