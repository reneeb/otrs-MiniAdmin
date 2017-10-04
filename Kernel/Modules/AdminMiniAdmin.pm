# --
# Copyright (C) 2017 Perl-Services.de, http://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminMiniAdmin;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::System::Log
    Kernel::System::Web::Request
    Kernel::Output::HTML::Layout
    Kernel::System::SysConfig
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

    my %Selected = map{ $_ => 1 } $ParamObject->GetArray( Param => 'FrontendModules' );

    my $FrontendModules = $ConfigObject->Get('Frontend::Module') || {};
    my @AdminModules    = grep{ m{\AAdmin}xms } sort keys %{ $FrontendModules };
    my $GroupName       = 'otrsminiadmin';

    if ( !$Self->{Subaction} || $Self->{Subaction} ne 'Save' ) {
        my @SelectedActions;

        for my $Module ( @AdminModules ) {
            my $HasGroup = grep{ $_ eq $GroupName }@{ $FrontendModules->{$Module}->{Group} || [] };
            push @SelectedActions, $Module if $HasGroup;
        }

        my $FrontendModulesSelect = $LayoutObject->BuildSelection(
            Name         => 'FrontendModules',
            Class        => 'Modernize',
            Data         => \@AdminModules,
            SelectedID   => \@SelectedActions,
            Translation  => 0,
            PossibleNone => 1,
            Multiple     => 1,
        );

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminMiniAdmin',
            Data         => {
                FrontendModules => $FrontendModulesSelect,
            },
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }
    else {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        MODULE:
        for my $Module ( @AdminModules ) {
            my @Groups     = @{ $FrontendModules->{$Module}->{Group} || [] };
            my $HasGroup   = grep{ $_ eq $GroupName }@Groups;
            my $IsSelected = $Selected{$Module};

            if ( ( $HasGroup && $IsSelected ) || ( !$HasGroup && !$IsSelected ) ) {
                next MODULE;
            }

            if ( !$IsSelected ) { # no longer a miniadmin item
                @Groups = grep{ $_ ne $GroupName }@Groups;
            }
            else { # a new miniadmin item
                push @Groups, $GroupName;
            }

            $FrontendModules->{$Module}->{Group} = \@Groups;

            my $Success = $SysConfigObject->ConfigItemUpdate(
                Valid => 1,
                Key   => 'Frontend::Module###' . $Module,
                Value => $FrontendModules->{$Module},
            );
        }

        return $LayoutObject->Redirect( OP => "Action=AdminMiniAdmin" );
    }

}

1;
