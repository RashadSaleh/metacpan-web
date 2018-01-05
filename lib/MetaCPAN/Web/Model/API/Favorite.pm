package MetaCPAN::Web::Model::API::Favorite;
use Moose;
use namespace::autoclean;

extends 'MetaCPAN::Web::Model::API';

use List::Util qw(uniq);
use Future;

sub get {
    my ( $self, $user, @distributions ) = @_;
    @distributions = uniq @distributions;

    # If there are no distributions this will build a query with an empty
    # filter and ES will return a parser error... so just skip it.
    if ( !@distributions ) {
        return Future->wrap( {} );
    }

    return $self->request( '/favorite/agg_by_distributions',
        { user => $user, distribution => \@distributions } );
}

sub by_user {
    my ( $self, $user, $size ) = @_;
    $size ||= 250;
    my $ret
        = $self->request( "/favorite/by_user/$user", { size => $size } )
        ->transform(
        done => sub {
            my $data = shift;
            return [] unless exists $data->{favorites};
            return $data->{favorites};
        }
        );
}

sub recent {
    my ( $self, $page, $page_size ) = @_;
    $self->request( '/favorite/recent',
        { size => $page_size, page => $page } )->then( sub {
        my $data = shift;
        my @user_ids = map { $_->{user} } @{ $data->{favorites} };
        return Future->done unless @user_ids;
        $self->request( '/author/by_user', undef, { user => \@user_ids } )
            ->transform(
            done => sub {
                my $authors = shift;
                if ( $authors and exists $authors->{authors} ) {
                    my %author_for_user_id
                        = map { $_->{user} => $_->{pauseid} }
                        @{ $authors->{authors} };
                    for my $fav ( @{ $data->{favorites} } ) {
                        next
                            unless exists $author_for_user_id{ $fav->{user} };
                        $fav->{clicked_by_author}
                            = $author_for_user_id{ $fav->{user} };
                    }
                }
                return $data;
            }
            );
        } );
}

sub leaderboard {
    my ($self) = @_;
    $self->request('/favorite/leaderboard');
}

sub find_plussers {
    my ( $self, $distribution ) = @_;

    # search for all users, match all according to the distribution.
    $self->request("/favorite/users_by_distribution/$distribution")
        ->then( sub {
        my $plusser_data = shift;
        my @plusser_users
            = $plusser_data->{users} ? @{ $plusser_data->{users} } : ();

        $self->get_plusser_authors( \@plusser_users )->then( sub {
            my @plusser_authors = @{ +shift };
            return Future->done( {
                plusser_authors => \@plusser_authors,
                plusser_others => scalar( @plusser_users - @plusser_authors ),
                plusser_data   => $distribution
            } );
        } );
        } );
}

sub get_plusser_authors {
    my ( $self, $users ) = @_;
    return Future->done( [] ) unless $users and @{$users};

    $self->request( '/author/by_user', { user => $users } )->transform(
        done => sub {
            my $res = shift;
            return [] unless $res->{authors};

            return [
                map +{
                    id  => $_->{pauseid},
                    pic => $_->{gravatar_url},
                },
                @{ $res->{authors} }
            ];
        }
    );
}

__PACKAGE__->meta->make_immutable;

1;
