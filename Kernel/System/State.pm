# --
# Kernel/System/State.pm - All state related function should be here eventually
# Copyright (C) 2001-2011 OTRS AG, http://otrs.org/
# --
# $Id: State.pm,v 1.49 2011/02/11 14:42:13 bes Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::State;

use strict;
use warnings;

use Kernel::System::Valid;
use Kernel::System::Time;
use Kernel::System::SysConfig;
use Kernel::System::CacheInternal;

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.49 $) [1];

=head1 NAME

Kernel::System::State - state lib

=head1 SYNOPSIS

All state functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::Encode;
    use Kernel::System::Log;
    use Kernel::System::Time;
    use Kernel::System::Main;
    use Kernel::System::DB;
    use Kernel::System::State;

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
    my $StateObject = Kernel::System::State->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        DBObject     => $DBObject,
        MainObject   => $MainObject,
        EncodeObject => $EncodeObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for (qw(DBObject ConfigObject LogObject MainObject EncodeObject)) {
        $Self->{$_} = $Param{$_} || die "Got no $_!";
    }

    # create addititional objects
    $Self->{ValidObject}         = Kernel::System::Valid->new(%Param);
    $Self->{CacheInternalObject} = Kernel::System::CacheInternal->new(
        %Param,
        Type => 'State',
        TTL  => 60 * 60 * 3,
    );

    # check needed config options
    for (qw(Ticket::ViewableStateType Ticket::UnlockStateType)) {
        $Self->{ConfigObject}->Get($_) || die "Need $_ in Kernel/Config.pm!\n";
    }

    return $Self;
}

=item StateAdd()

add new states

    my $ID = $StateObject->StateAdd(
        Name    => 'New State',
        Comment => 'some comment',
        ValidID => 1,
        TypeID  => 1,
        UserID  => 123,
    );

=cut

sub StateAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name ValidID TypeID UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # store data
    return if !$Self->{DBObject}->Do(
        SQL => 'INSERT INTO ticket_state (name, valid_id, type_id, comments,'
            . ' create_time, create_by, change_time, change_by)'
            . ' VALUES (?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{TypeID}, \$Param{Comment},
            \$Param{UserID}, \$Param{UserID},
        ],
    );

    # get new state id
    return if !$Self->{DBObject}->Prepare(
        SQL  => 'SELECT id FROM ticket_state WHERE name = ?',
        Bind => [ \$Param{Name} ],
    );
    my $ID;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $ID = $Row[0];
    }
    return if !$ID;

    # delete cache
    $Self->{CacheInternalObject}->Delete( Key => 'StateGet::Name::' . $Param{Name}, );
    $Self->{CacheInternalObject}->Delete( Key => 'StateGet::ID::' . $ID, );

    return $ID;
}

=item StateGet()

get state attributes

    my %State = $StateObject->StateGet(
        Name  => 'New State',
    );

    my %State = $StateObject->StateGet(
        ID    => 123,
    );

returns

    my %State = (
        Name       => "new",
        ID         => 1,
        TypeName   => "new",
        TypeID     => 1,
        ValidID    => 1,
        CreateTime => "2010-11-29 11:04:04",
        ChangeTime => "2010-11-29 11:04:04",
        Comment    => "New ticket created by customer.",
    );

=cut

sub StateGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} && !$Param{Name} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need ID or Name!" );
        return;
    }

    # check cache
    my $CacheKey;
    if ( $Param{Name} ) {
        $CacheKey = 'StateGet::Name::' . $Param{Name};
    }
    else {
        $CacheKey = 'StateGet::ID::' . $Param{ID};
    }
    my $Cache = $Self->{CacheInternalObject}->Get( Key => $CacheKey );
    return %{$Cache} if $Cache;

    # sql
    my @Bind;
    my $SQL = 'SELECT ts.id, ts.name, ts.valid_id, ts.comments, ts.type_id, tst.name,'
        . ' ts.change_time, ts.create_time'
        . ' FROM ticket_state ts, ticket_state_type tst WHERE ts.type_id = tst.id AND ';
    if ( $Param{Name} ) {
        $SQL .= ' ts.name = ?';
        push @Bind, \$Param{Name};
    }
    else {
        $SQL .= ' ts.id = ?';
        push @Bind, \$Param{ID};
    }
    return if !$Self->{DBObject}->Prepare( SQL => $SQL, Bind => \@Bind );
    my %Data;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        %Data = (
            ID         => $Data[0],
            Name       => $Data[1],
            Comment    => $Data[3],
            ValidID    => $Data[2],
            TypeID     => $Data[4],
            TypeName   => $Data[5],
            ChangeTime => $Data[6],
            CreateTime => $Data[7],
        );
    }

    # set cache
    $Self->{CacheInternalObject}->Set(
        Key   => $CacheKey,
        Value => \%Data,
    );

    # no data found...
    if ( !%Data ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "State '$Param{Name}' not found!"
        );
        return;
    }

    # return data
    return %Data;
}

=item StateUpdate()

update state attributes

    $StateObject->StateUpdate(
        ID             => 123,
        Name           => 'New State',
        Comment        => 'some comment',
        ValidID        => 1,
        TypeID         => 1,
        CheckSysConfig => 0,   # (optional) default 1
        UserID         => 123,
    );

=cut

sub StateUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID Name ValidID TypeID UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # check CheckSysConfig param
    if ( !defined $Param{CheckSysConfig} ) {
        $Param{CheckSysConfig} = 1;
    }

    # sql
    return if !$Self->{DBObject}->Do(
        SQL => 'UPDATE ticket_state SET name = ?, comments = ?, type_id = ?, '
            . ' valid_id = ?, change_time = current_timestamp, change_by = ? '
            . ' WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{Comment}, \$Param{TypeID}, \$Param{ValidID},
            \$Param{UserID}, \$Param{ID},
        ],
    );

    # delete cache
    $Self->{CacheInternalObject}->Delete( Key => 'StateGet::Name::' . $Param{Name}, );
    $Self->{CacheInternalObject}->Delete( Key => 'StateGet::ID::' . $Param{ID} );

    # create a time object locally, needed for the local SysConfigObject
    my $TimeObject = Kernel::System::Time->new( %{$Self} );

    # check all sysconfig options
    if ( $Param{CheckSysConfig} ) {

        # create a sysconfig object locally for performance reasons
        my $SysConfigObject = Kernel::System::SysConfig->new(
            %{$Self},
            TimeObject => $TimeObject,
        );

        # check all sysconfig options and correct them automatically if neccessary
        $SysConfigObject->ConfigItemCheckAll();
    }

    return 1;
}

=item StateGetStatesByType()

get list of states for a type or a list of state types

    get all states with state type open and new
    (available: new, open, closed, pending reminder, pending auto,
    removed, merged)

    my @List = $StateObject->StateGetStatesByType(
        StateType => ['open', 'new'],
        Result    => 'ID', # HASH|ID|Name
    );

    get all state types used by config option named like

    Ticket::ViewableStateType for "Viewable" state types

    my %List = $StateObject->StateGetStatesByType(
        Type   => 'Viewable',
        Result => 'HASH', # HASH|ID|Name
    );

=cut

sub StateGetStatesByType {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Result} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => 'Need Result!' );
        return;
    }

    if ( !$Param{Type} && !$Param{StateType} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => 'Need Type or StateType!' );
        return;
    }

    # cache key
    my $CacheKey = 'StateGetStatesByType::';
    if ( $Param{Type} ) {
        $CacheKey .= 'Type::' . $Param{Type};
    }
    if ( $Param{StateType} ) {

        my @StateType;
        if ( ref $Param{StateType} eq 'ARRAY' ) {
            @StateType = @{ $Param{StateType} };
        }
        else {
            push @StateType, $Param{StateType};
        }
        $CacheKey .= 'StateType::' . join ':', sort @StateType;
    }

    # check cache
    my $Cache = $Self->{CacheInternalObject}->Get( Key => $CacheKey );
    if ($Cache) {
        if ( $Param{Result} eq 'Name' ) {
            return @{ $Cache->{Name} };
        }
        elsif ( $Param{Result} eq 'HASH' ) {
            return %{ $Cache->{HASH} };
        }
        return @{ $Cache->{ID} };
    }

    # sql
    my @StateType;
    my @Name;
    my @ID;
    my %Data;
    if ( $Param{Type} ) {
        if ( $Self->{ConfigObject}->Get( 'Ticket::' . $Param{Type} . 'StateType' ) ) {
            @StateType = @{ $Self->{ConfigObject}->Get( 'Ticket::' . $Param{Type} . 'StateType' ) };
        }
        else {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Type 'Ticket::$Param{Type}StateType' not found in Kernel/Config.pm!",
            );
            die;
        }
    }
    else {
        if ( ref $Param{StateType} eq 'ARRAY' ) {
            @StateType = @{ $Param{StateType} };
        }
        else {
            push @StateType, $Param{StateType};
        }
    }
    my $SQL = "SELECT ts.id, ts.name, tst.name  "
        . " FROM ticket_state ts, ticket_state_type tst WHERE "
        . " tst.id = ts.type_id AND "
        . " tst.name IN ('${\(join '\', \'', sort @StateType)}' ) AND "
        . " ts.valid_id IN ( ${\(join ', ', $Self->{ValidObject}->ValidIDsGet())} )";
    return if !$Self->{DBObject}->Prepare( SQL => $SQL );

    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        push @Name, $Data[1];
        push @ID,   $Data[0];
        $Data{ $Data[0] } = $Data[1];
    }

    # set runtime cache
    my $All = {
        Name => \@Name,
        ID   => \@ID,
        HASH => \%Data,
    };

    # set permanent cache
    $Self->{CacheInternalObject}->Set(
        Key   => $CacheKey,
        Value => $All,
    );

    if ( $Param{Result} eq 'Name' ) {
        return @Name;
    }
    elsif ( $Param{Result} eq 'HASH' ) {
        return %Data;
    }
    return @ID;
}

=item StateList()

get state list as a hash of ID, Name pairs

    my %List = $StateObject->StateList(
        UserID => 123,
    );

    my %List = $StateObject->StateList(
        UserID => 123,
        Valid  => 1, # is default
    );

    my %List = $StateObject->StateList(
        UserID => 123,
        Valid  => 0,
    );

returns

    my %List = (
        1 => "new",
        2 => "closed successful",
        3 => "closed unsuccessful",
        4 => "open",
        5 => "removed",
        6 => "pending reminder",
        7 => "pending auto close+",
        8 => "pending auto close-",
        9 => "merged",
    );

=cut

sub StateList {
    my ( $Self, %Param ) = @_;

    my $Valid = 1;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => 'UserID!' );
        return;
    }
    if ( !$Param{Valid} && defined( $Param{Valid} ) ) {
        $Valid = 0;
    }

    # sql
    my $SQL = 'SELECT id, name FROM ticket_state';
    if ($Valid) {
        $SQL .= " WHERE valid_id IN ( ${\(join ', ', $Self->{ValidObject}->ValidIDsGet())} )";
    }
    return if !$Self->{DBObject}->Prepare( SQL => $SQL );
    my %Data;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }
    return %Data;
}

=item StateLookup()

returns the id or the name of a state

    my $StateID = $StateObject->StateLookup(
        State => 'closed successful',
    );

    my $State = $StateObject->StateLookup(
        StateID => 2,
    );

=cut

sub StateLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{State} && !$Param{StateID} ) {
        $Self->{LogObject}->Log( State => 'error', Message => 'Need State or StateID!' );
        return;
    }

    # check cache
    my $CacheKey;
    my $Key;
    my $Value;
    if ( $Param{State} ) {
        $Key      = 'State';
        $Value    = $Param{State};
        $CacheKey = 'StateLookup::Name::' . $Param{State};
    }
    else {
        $Key      = 'StateID';
        $Value    = $Param{StateID};
        $CacheKey = 'StateLookup::ID::' . $Param{StateID};
    }

    my $Cache = $Self->{CacheInternalObject}->Get( Key => $CacheKey );
    return $Cache if $Cache;

    # db query
    my $SQL;
    my @Bind;
    if ( $Param{State} ) {
        $SQL = 'SELECT id FROM ticket_state WHERE name = ?';
        push @Bind, \$Param{State};
    }
    else {
        $SQL = 'SELECT name FROM ticket_state WHERE id = ?';
        push @Bind, \$Param{StateID};
    }
    return if !$Self->{DBObject}->Prepare( SQL => $SQL, Bind => \@Bind );
    my $Data;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $Data = $Row[0];
    }

    # set cache
    $Self->{CacheInternalObject}->Set( Key => $CacheKey, Value => $Data );

    # check if data exists
    if ( !defined $Data ) {
        $Self->{LogObject}->Log(
            State   => 'error',
            Message => "No $Key for $Value found!",
        );
        return;
    }

    return $Data;
}

=item StateTypeList()

get state type list as a hash of ID, Name pairs

    my %ListType = $StateObject->StateTypeList(
        UserID => 123,
    );

returns

    my %ListType = (
        1 => "new",
        2 => "open",
        3 => "closed",
        4 => "pending reminder",
        5 => "pending auto",
        6 => "removed",
        7 => "merged",
    );

=cut

sub StateTypeList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => 'UserID!' );
        return;
    }

    # sql
    return if !$Self->{DBObject}->Prepare(
        SQL => 'SELECT id, name FROM ticket_state_type',
    );
    my %Data;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }
    return %Data;
}

=item StateTypeLookup()

returns the id or the name of a state type

    my $StateTypeID = $StateTypeObject->StateTypeLookup(
        StateType => 'pending auto',
    );

    my $StateType = $StateTypeObject->StateTypeLookup(
        StateTypeID => 1,
    );

=cut

sub StateTypeLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{StateType} && !$Param{StateTypeID} ) {
        $Self->{LogObject}
            ->Log( StateType => 'error', Message => 'Need StateType or StateTypeID!' );
        return;
    }

    # check cache
    my $CacheKey;
    my $Key;
    my $Value;
    if ( $Param{StateType} ) {
        $Key      = 'StateType';
        $Value    = $Param{StateType};
        $CacheKey = 'StateTypeLookup::Name::' . $Param{StateType};
    }
    else {
        $Key      = 'StateTypeID';
        $Value    = $Param{StateTypeID};
        $CacheKey = 'StateTypeLookup::ID::' . $Param{StateTypeID};
    }

    my $Cache = $Self->{CacheInternalObject}->Get( Key => $CacheKey );
    return $Cache if $Cache;

    # db query
    my $SQL;
    my @Bind;
    if ( $Param{StateType} ) {
        $SQL = 'SELECT id FROM ticket_state_type WHERE name = ?';
        push @Bind, \$Param{StateType};
    }
    else {
        $SQL = 'SELECT name FROM ticket_state_type WHERE id = ?';
        push @Bind, \$Param{StateTypeID};
    }
    return if !$Self->{DBObject}->Prepare( SQL => $SQL, Bind => \@Bind );
    my $Data;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $Data = $Row[0];
    }

    # set cache
    $Self->{CacheInternalObject}->Set( Key => $CacheKey, Value => $Data );

    # check if data exists
    if ( !defined $Data ) {
        $Self->{LogObject}->Log(
            StateType => 'error',
            Message   => "No $Key for $Value found!",
        );
        return;
    }

    return $Data;
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

$Revision: 1.49 $ $Date: 2011/02/11 14:42:13 $

=cut