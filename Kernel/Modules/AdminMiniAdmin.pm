# --
# Copyright (C) 2017 - 2021 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminMiniAdmin;

use strict;
use warnings;

use Kernel::Language qw(Translatable);
use Kernel::System::VariableCheck qw(DataIsDifferent);

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::System::Log
    Kernel::System::Web::Request
    Kernel::Output::HTML::Layout
    Kernel::System::SysConfig
    Kernel::System::Group
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject     = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
    my $GroupObject     = $Kernel::OM->Get('Kernel::System::Group');

    if ( !$Self->{Subaction} || $Self->{Subaction} ne 'Save' ) {
        my $NavigationItems = $ConfigObject->Get('Frontend::NavigationModule') || {};
        my %AdminModules    =
            map{ $_ => $NavigationItems->{$_}->{Name} }
            grep{ m{\AAdmin.+}xms && exists $NavigationItems->{$_} }
            sort keys %{ $NavigationItems };

        my $FrontendModulesSelect = $LayoutObject->BuildSelection(
            Name         => 'FrontendModules_#GroupName',
            Class        => 'W100pc Modernize',
            Data         => \%AdminModules,
            Translation  => 1,
            PossibleNone => 1,
            Multiple     => 1,
            Size         => 10,
        );

        my %Groups = $GroupObject->GroupList();
        my %ReverseGroups = reverse %Groups;

        my %MiniAdminActions;
        for my $Widget ( keys %{ $NavigationItems } ) {
            for my $Group ( @{ $NavigationItems->{$Widget}->{Group} || [] } ) {
                push @{ $MiniAdminActions{$Group} }, $Widget;

                delete $Groups{ $ReverseGroups{$Group} };
            }
        }

        my $MiniAdmins = $LayoutObject->JSONEncode( Data => [
            map { +{ name => $_, actions => $MiniAdminActions{$_} } }
            sort keys %MiniAdminActions
        ] );

        my $GroupsSelect = $LayoutObject->BuildSelection(
            Name         => 'GroupID',
            Class        => 'Modernize',
            Data         => \%Groups,
            Translation  => 0,
            PossibleNone => 1,
        );

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminMiniAdmin',
            Data         => {
                FrontendModules => $FrontendModulesSelect,
                GroupsSelect    => $GroupsSelect,
                MiniAdmins      => $MiniAdmins,
            },
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }
    else {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my @SysConfigSettings;

        my $NavigationItems = $ConfigObject->Get('Frontend::NavigationModule') || {};
        my $FrontendModules = $ConfigObject->Get('Frontend::Module') || {};
        my $FrontendNavi    = $ConfigObject->Get('Frontend::Navigation') || {};

        my $FrontendNavigationAdmin = $FrontendNavi->{Admin}->{'001-Framework'};

        my @ParamNames = grep{ $_ =~ m{\AFrontendModules_.*} } $ParamObject->GetParamNames();
        my %Selected;
        my %AllGroups;

        for my $ParamName ( @ParamNames ) {
            (my $Group = $ParamName) =~ s{\AFrontendModules_}{}xms;

            for my $Widget ( $ParamObject->GetArray( Param => $ParamName ) ) {
                $Selected{$Widget}->{$Group} = 1;
                $AllGroups{$Group} = 1;
            }
        }

        delete $AllGroups{users};

        my %NavigationGroups = map { $_ => 1 } @{ $FrontendNavigationAdmin->[0]->{Group} || [] };
        if ( DataIsDifferent( Data1 => \%NavigationGroups, Data2 => \%AllGroups ) ) { 
            $FrontendNavigationAdmin->[0]->{Group}  = [ sort keys %AllGroups ];

            push @SysConfigSettings, (
                # show 'Admin' in navigation bar
                {
                    Name   => 'Frontend::Navigation###Admin###001-Framework',
                    EffectiveValue => $FrontendNavigationAdmin,
                },
            );
        }

        my %FrontendGroups = map { $_ => 1 } @{ $FrontendModules->{Admin}->{Group} || [] };
        if ( DataIsDifferent( Data1 => \%NavigationGroups, Data2 => \%AllGroups ) ) { 
            $FrontendModules->{Admin}->{Group} = [ sort keys %AllGroups ];

            # activate admin area for all groups with mini admin permissions
            push @SysConfigSettings, (
                # access to action
                {
                    Name   => 'Frontend::Module###Admin',
                    EffectiveValue => $FrontendModules->{Admin},
                },
            );
        }

        WIDGET:
        for my $Widget ( sort keys %Selected ) {
            my %WidgetGroups = map{ $_ => 1 } @{ $NavigationItems->{$Widget}->{Group} || [] };
            my %NewGroups    = %{ $Selected{$Widget} || {} };

            if ( !DataIsDifferent( Data1 => \%WidgetGroups, Data2 => \%NewGroups ) ) {
                next WIDGET;
            }

            $NavigationItems->{$Widget}->{Group} = [ sort keys %NewGroups ];

            push @SysConfigSettings, (
                # access to action
                {
                    Name   => 'Frontend::NavigationModule###' . $Widget,
                    EffectiveValue => $NavigationItems->{$Widget},
                },
            );
        }

        if ( @SysConfigSettings ) {
            my $Success = $SysConfigObject->SettingsSet(
                UserID   => $Self->{UserID},
                Settings => \@SysConfigSettings,
                Comments => 'Changed MiniAdminSettings',
            );
        }

        return $LayoutObject->Redirect( OP => "Action=AdminMiniAdmin" );
    }
}

1;
