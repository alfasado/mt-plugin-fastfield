package FastField::CMS;
#use strict;

sub download_cf_yaml {
    my $app = shift;
    my $user = $app->user;
    unless ($user->is_superuser) {
        return $app->trans_error( 'Permission denied.' );
    }
    require CustomFields::Field;
    $app->{ no_print_body } = 1;
    $app->set_header( 'Content-Disposition' => 'attachment; filename=Fields.yaml' );
    $app->send_http_header( 'text/yaml' );
    my $iter = CustomFields::Field->load_iter( undef );
    require YAML::Tiny;
    while ( my $field = $iter->() ) {
        my $tag = $field->tag;
        my $obj_type = $field->obj_type;
        my $basename = $field->basename;
        my $type = $field->type;
        my $blog_id = $field->blog_id;
        my $yaml = YAML::Tiny->new;
        $yaml->[ 0 ]->{ $basename . '.' . $blog_id } =
                      { obj_type => $obj_type,
                        basename => $basename,
                        blog_id  => $blog_id,
                        tag      => $tag,
                        type     => $type,
                        $field->has_column( 'customobject' ) ? ( customobject => $field->customobject ) : (),
                        $field->has_column( 'customgroup' ) ? ( customgroup => $field->customgroup ) : (),
                      };
        my $section = $yaml->write_string();
        $section =~ s!---\n!!g;
        $app->print_encode( "$section" );
    }
}

sub post_change_field {
    my ( $cb, $obj ) = @_;
    require MT::Request;
    my $r = MT::Request->instance;
    my $k = 'plugin-fastfield-post_save_field:' . $obj->id;
    if ( my $cache = $r->cache( $k ) ) {
        return 1;
    }
    require MT::Memcached;
    if ( MT::Memcached->is_available ) {
        my $memcached = MT::Memcached->instance;
        $memcached->set( 'plugin-fastfield-YAML' => undef );
    }
    $r->cache( $k, 1 );
    return 1;
}

1;
