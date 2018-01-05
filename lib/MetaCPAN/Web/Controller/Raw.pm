package MetaCPAN::Web::Controller::Raw;

use Moose;
use namespace::autoclean;

BEGIN { extends 'MetaCPAN::Web::Controller' }

sub index : Path : Args {
    my ( $self, $c, @module ) = @_;

    my ( $source, $module ) = map { $_->get } (
        $c->model('API::Module')->source(@module),
        $c->model('API::Module')->get(@module),
    );
    $c->detach('/not_found') unless ( $source->{raw} );
    if ( $c->req->parameters->{download} ) {
        my $content_disposition = 'attachment';
        if ( my $filename = $module->{name} ) {
            $content_disposition .= "; filename=$filename";
        }
        $c->res->body( $source->{raw} );
        $c->res->content_type('text/plain');
        $c->res->header( 'Content-Disposition' => $content_disposition );
    }
    else {
        $c->stash( {
            source   => $source->{raw},
            module   => $module,
            template => 'raw.html'
        } );
    }
}

__PACKAGE__->meta->make_immutable;

1;
