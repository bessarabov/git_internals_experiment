#!/usr/bin/perl

=encoding UTF-8
=cut

=head1 DESCRIPTION

=cut

# common modules
use strict;
use warnings FATAL => 'all';
use feature 'say';
use utf8;
use open qw(:std :utf8);

use boolean;
use DDP;
use Carp;
use Git::Repository;
use File::Temp qw(tempdir);

use lib::abs qw(
    ./lib
);

# global vars
my %FILES;

# subs
sub clean_env {
    delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
    $ENV{LC_ALL} = 'C';
}

sub get_tmp_dir {
    my $tmp_dir = tempdir( CLEANUP => false );

    return $tmp_dir;
}

sub git_init {
    my ($tmp_dir) = @_;

    Git::Repository->run( init => $tmp_dir );
}

sub get_git_repository_object {
    my ($tmp_dir) = @_;

    my $gr = Git::Repository->new( work_tree => $tmp_dir );

    return $gr;
}

sub set_commiter {
    my (%params) = @_;

    $ENV{GIT_AUTHOR_NAME} = $params{name};
    $ENV{GIT_AUTHOR_EMAIL} = $params{email};
    $ENV{GIT_COMMITTER_NAME}  = $params{name};
    $ENV{GIT_COMMITTER_EMAIL} = $params{email};
}

sub set_date {
    my ($date) = @_;

    $ENV{GIT_AUTHOR_DATE} = $date;
    $ENV{GIT_COMMITTER_DATE} = $date;

}

sub create_blob_object {
    my (%params) = @_;

    my $sha1 = $params{gr}->run(
        qw( hash-object -t blob -w --stdin ),
        { input => $params{content} },
    );

    return $sha1;
}

sub create_tree_object {
    my (%params) = @_;

    my $content = '';

    foreach my $file_data (@{$params{files}}) {
        $content .= "100644 blob $file_data->{sha1}\t$file_data->{name}\n";
    }

    $params{gr}->run( mktree => { input => $content } );
}

sub create_blobs_and_tree {
    my (%params) = @_;

    my @files;

    foreach my $file_name (keys %FILES) {
        push @files, {
            name => $file_name,
            sha1 => create_blob_object(
                gr => $params{gr},
                content => $FILES{$file_name},
            ),
        }
    }

    my $tree_sha1 = create_tree_object(
        gr => $params{gr},
        files => \@files,
    );

    return $tree_sha1;
}

sub commit {
    my (%params) = @_;

    if (@{$params{parents}} == 0 or @{$params{parents}} == 1) {
        # ok
    } else {
        croak 'Incorrect usage';
    }

    my $commit_sha1 = $params{gr}->run(
        'commit-tree' => $params{tree_sha1},
        (
            ( @{$params{parents}} == 1 )
                ? ('-p' => $params{parents}->[0])
                : ()
        ),
        { input => $params{message} },
    );

    return $commit_sha1;
}


sub make_first_commit {
    my (%params) = @_;

    my $gr = delete $params{gr};

    $FILES{'aaa.md'} = "line 1\nline 2\nline 3\n";

    my $tree_sha1 = create_blobs_and_tree(
        gr => $gr,
        files => \%FILES,
    );

    set_commiter(
        name => 'Robot 1',
        email => 'robot_1@example.com',
    );

    set_date( '2001-01-01 00:00:00 +0000' );

    my $commit_sha1 = commit(
        gr => $gr,
        tree_sha1 => $tree_sha1,
        parents => [],
        message => 'First commit',
    );

    $gr->run( 'update-ref', 'refs/heads/master' => $commit_sha1 );

    return $commit_sha1;
}

sub make_second_commit {
    my (%params) = @_;

    my $gr = delete $params{gr};

    $FILES{'aaa.md'} = "line 1\nline 22\nline 3\n";

    my $tree_sha1 = create_blobs_and_tree(
        gr => $gr,
        files => \%FILES,
    );

    set_commiter(
        name => 'Robot 2',
        email => 'robot_2@example.com',
    );

    set_date( '2002-01-01 00:00:00 +0000' );

    my $commit_sha1 = commit(
        gr => $gr,
        tree_sha1 => $tree_sha1,
        parents => $params{parents},
        message => 'Second commit',
    );

    $gr->run( 'update-ref', 'refs/heads/master' => $commit_sha1 );

    return $commit_sha1;
}

sub make_third_commit {
    my (%params) = @_;

    my $gr = delete $params{gr};

    $FILES{'bbb.md'} = '';
    $FILES{'ccc.md'} = '';

    my $tree_sha1 = create_blobs_and_tree(
        gr => $gr,
        files => \%FILES,
    );

    set_commiter(
        name => 'Robot 2',
        email => 'robot_2@example.com',
    );

    set_date( '2003-01-01 00:00:00 +0000' );

    my $commit_sha1 = commit(
        gr => $gr,
        tree_sha1 => $tree_sha1,
        parents => $params{parents},
        message => 'Third commit',
    );

    $gr->run( 'update-ref', 'refs/heads/master' => $commit_sha1 );

    return $commit_sha1;
}

# main
sub main {

    clean_env();
    my $tmp_dir = get_tmp_dir();

    say "Git working copy $tmp_dir";

    git_init( $tmp_dir );
    my $gr = get_git_repository_object( $tmp_dir );

    my $sha1_1 = make_first_commit( gr => $gr );
    my $sha1_2 = make_second_commit( gr => $gr, parents => [$sha1_1] );
    my $sha1_3 = make_third_commit( gr => $gr, parents => [$sha1_2] );

    say '#END';

}
main();
__END__
