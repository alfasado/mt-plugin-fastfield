package MT::Plugin::FastField;
use strict;
use MT;
use MT::Plugin;
use base qw( MT::Plugin );
use lib qw( addons/Commercial.pack/lib );

@MT::Plugin::FastField::ISA = qw( MT::Plugin );

my $plugin = __PACKAGE__->new( {
    id   => 'FastField',
    key  => 'fastfield',
    name => 'Fast Field',
    author_name => 'Alfasado Inc.',
    author_link => 'http://alfasado.net/',
    description => '<__trans phrase="Fast Loading CustomField.">',
    version => '0.1',
} );

sub init_registry {
    my $plugin = shift;
    $plugin->registry( {
        applications => {
            cms => {
                methods => {
                    download_cf_yaml =>
                        '$fastfield::FastField::CMS::download_cf_yaml',
                },
                menus => {
                    'custom_fields:download_cf_yaml' => {
                        label => 'Download YAML',
                        mode  => 'download_cf_yaml',
                        order => 1000,
                        permission => 'administer',
                        view => [ 'system' ],
                    },
                },
            },
        },
        callbacks => {
            'CustomFields::Field::post_save' =>
                '$fastfield::FastField::CMS::post_change_field',
            'CustomFields::Field::post_delete' =>
                '$fastfield::FastField::CMS::post_change_field',
        },
        config_settings => {
            'LoadCustomFieldMode' => {
                type => 'ARRAY',
                default => [ 'view', 'rebuild', 'preview', 'save', 'delete' ],
            },
        },
    } );
}

MT->add_plugin( $plugin );
{
    require CustomFields::Util;
    no warnings 'redefine';
    *CustomFields::Util::load_meta_fields = sub {
        my $app = MT->instance();
        require MT::Request;
        my $r = MT::Request->instance;
        my $cache = $r->cache( 'plugin-fastfield-init' );
        return 1 if $cache;
        $r->cache( 'plugin-fastfield-init', 1 );
        # require Time::HiRes;
        # my $start = Time::HiRes::time();
        if ( ref $app eq 'MT::App::CMS' ) {
            my $load_at = $app->config( 'LoadCustomFieldMode' );
            require CGI;
            my $q = new CGI;
            my $mode = $q->param( '__mode' );
            return unless $mode;
            $mode =~ s/_.*$//;
            if (! grep( /^$mode$/, @$load_at ) ) {
                # my $end = Time::HiRes::time();
                # MT->log( $end - $start );
                return;
            }
        }
        require File::Spec;
        require CustomFields::Field;
        require YAML::Tiny;
        require MT::Memcached;
        my $yaml;
        my $memcached;
        my ( @fields, %meta );
        my $master = File::Spec->catfile( $plugin->path, 'yaml', 'Fields.yaml' );
        if ( MT::Memcached->is_available ) {
            $memcached = MT::Memcached->instance;
            my $chached = $memcached->get( 'plugin-fastfield-init' );
            my $yamlmodified;
            $yamlmodified = ( stat $master )[9] if $master;
            if ( $yamlmodified && ( $yamlmodified > $chached ) ) {
            } else {
                $yaml = $memcached->get( 'plugin-fastfield-YAML' );
            }
        }
        if (! $yaml ) {
            if (-f $master ) {
                $yaml = YAML::Tiny::LoadFile( $master );
                if ( $memcached && $yaml ) {
                    $memcached->set( 'plugin-fastfield-YAML' => $yaml );
                    $memcached->set( 'plugin-fastfield-init' => time() );
                }
            }
        }
        if (! $yaml ) {
            my $iter = eval {
                require MT::Object;
                my $driver = MT::Object->driver;
                require CustomFields::Field;
                CustomFields::Field->load_iter;
            };
            return unless $iter;
            while ( my $field = $iter->() ) {
                my $id = $field->basename . '.' . $field->blog_id;
                $yaml->{ $id } = { basename => $field->basename,
                                   blog_id  => $field->blog_id,
                                   obj_type => $field->obj_type,
                                   tag => $field->tag,
                                   type => $field->type, };
            }
            if ( $memcached && $yaml ) {
                $memcached->set( 'plugin-fastfield-YAML' => $yaml );
                $memcached->set( 'plugin-fastfield-init' => time() );
            }
        }
        if ( $yaml ) {
            foreach my $cf ( keys %$yaml ) {
                my $record = $yaml->{ $cf };
                my $field = CustomFields::Field->new;
                $field->set_values( $record );
                push( @fields, $field );
                $meta{ $field->obj_type }{ 'field.' . $field->basename } = $field->type;
            }
        } else {
            return;
        }
        my $component = MT->component( 'commercial' );
        $component->{ customfields } = \@fields;
        if ( %meta ) {
            my $types = MT->registry( 'customfield_types' );
            foreach my $type ( keys %meta ) {
                my $ppkg = MT->model( $type );
                next unless $ppkg;
                my $fields = $meta{ $type };
                foreach my $field ( keys %$fields ) {
                    my $cf_type = $types->{ $fields->{ $field } };
                    if ( $cf_type ) {
                        $fields->{ $field } = $cf_type->{ column_def } || 'vblob';
                    } else {
                        delete $fields->{ $field };
                    }
                }
                $ppkg->install_meta( { column_defs => $meta{ $type } } );
            }
        }
        # my $end = Time::HiRes::time();
        # MT->log( $end - $start );
    };
};

1;