package App::CreateAcmeCPANModulesImportCPANRatingsModules;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Log::ger;
use Perinci::Sub::Util qw(err);

our %SPEC;

sub _url_to_filename {
    my $url = shift;
    $url =~ s![^A-Za-z0-9_.-]+!_!g;
    $url;
}

$SPEC{create_acme_cpanmodules_import_cpanratings_user_modules} = {
    v => 1.1,
    summary => 'Create Acme::CPANModules::Import::CPANRatings::User::* modules',
    description => <<'_',

An `Acme::CPANModules::Import::CPANRatings::User::*` module contains a module
list where its entries (modules) are extracted from CPANRatings user page. The
purpose of creating such module is to have a POD mentioning the modules, thus
adding/improving to the POD "mentions cloud" on CPAN.

_
    args => {
        users => {
            schema => ['array*', of=>['str*', match=>qr/\A\w+\z/]],
            req => 1,
        },
        cache => {
            schema => 'bool',
            default => 1,
        },
        user_agent => {
            summary => 'Set HTTP User-Agent',
            schema => 'str*',
        },
        dist_dir => {
            schema => 'str*',
        },
    },
};
sub create_acme_cpanmodules_import_cpanratings_user_modules {
    require Data::Dmp;
    require File::Slurper;
    require LWP::UserAgent;
    require POSIX;

    my %args = @_;

    my $users = $args{users};
    my $dist_dir = $args{dist_dir} // do { require Cwd; Cwd::get_cwd() };
    my $cache = $args{cache} // 1;

    my $ua = LWP::UserAgent->new;
    my $user_agent_str = $args{user_agent} // $ENV{HTTP_USER_AGENT};
    $ua->agent($user_agent_str) if $user_agent_str;

    my $now = time();

    my %names;
  AC_MOD:
    for my $user (@$users) {
        log_info("Processing user %s ...", $user);

        my $mod = "Acme::CPANModules::Import::CPANRatings::User::$user";
        (my $mod_path = "$dist_dir/lib/$mod.pm") =~ s!::!/!g;

        my $url = "https://cpanratings.perl.org/user/$user";

        my $cache_path = "$dist_dir/devdata/$user";
        my @st_cache = stat $cache_path;
        my $content;
        if (!$cache || !@st_cache || $st_cache[9] < $now-30*86400) {
            log_info("Retrieving %s ...", $url);
            my $resp = $ua->get($url, "Cache-Control" => "no-cache");
            $resp->is_success
                or return [500, "Can't get $url: ".$resp->status_line];
            $content = $resp->content;
            File::Slurper::write_text($cache_path, $content);
        } else {
            log_info("Using cache file %s", $cache_path);
            $content = File::Slurper::read_text($cache_path);
        }

        my @review_htmls;
        while ($content =~ m!<div class="review"(.+?)<div class="review_footer">!sg) {
            push @review_htmls, $1;
        }

        my @dists;
        for my $review_html (@review_htmls) {
            $review_html =~ m!<h3 class="review_header">.+?<a href="/dist/([^"]+)">(?:.+?/images/stars-(\d\.\d)\.png")?.+?<blockquote class="review_text">(.+?)</blockquote>!s or die;
            push @dists, {dist=>$1, rating=>$2, text=>$3};
        }

        my @mods;
        for my $dist (@dists) {
            (my $mod = $dist->{dist}) =~ s/-/::/g;
            push @mods, {
                module => $mod,
                rating => defined($dist->{rating}) ? $dist->{rating} * 2 : undef, # converted from 1-5 scale to 1-10 scale
                description => $dist->{text},
            };
        }

        my $mod_list = {
            summary => "Modules mentioned by CPANRatings user $user",
            description => "This list is generated by scraping CPANRatings (cpanratings.perl.org) user page.",
            entries => \@mods,
        };

        my @pm_content = (
            "package $mod;\n",
            "\n",
            "# DATE\n",
            "# VERSION\n",
            "\n",
            "our \$LIST = ", Data::Dmp::dmp($mod_list), ";\n",
            "\n",
            "1;\n",
            "# ABSTRACT: $mod_list->{summary}\n",
            "\n",
            "=head1 DESCRIPTION\n",
            "\n",
            $mod_list->{description}, "\n\n",
            "\n",
        );

        log_info("Writing module %s ...", $mod_path);
        File::Slurper::write_text($mod_path, join("", @pm_content));
    }

    [200];
}

1;
# ABSTRACT:

=head1 ENVIRONMENT

=head2 HTTP_USER_AGENT => str

Set default for C<user_agent> argument.


=head1 SEE ALSO

L<Acme::CPANModules>

Some C<Acme::CPANModules::Import::*> modules which utilize this during building:
L<Acme::CPANModulesBundle::Import::NEILB>,
L<Acme::CPANModules::Import::SHARYANTO>,
L<Acme::CPANModulesBundle::Import::RSAVAGE>, and so on.

L<App::lcpan>, L<lcpan>, especially the B<related-mods> subcommand.

=cut
