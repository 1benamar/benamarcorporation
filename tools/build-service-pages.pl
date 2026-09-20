#!/usr/bin/perl
# Genera las paginas de servicio a partir de los JSON de contenido.
# La cabecera y el pie se copian del index de cada idioma para que no se
# desincronicen; solo se reescriben los enlaces que cambian en una subpagina.
use strict;
use warnings;
use utf8;
use JSON::PP;
binmode(STDOUT, ':encoding(UTF-8)');

my @langs = @ARGV ? @ARGV : qw(es);
my (%data, %slug);

for my $l (@langs) {
    open my $f, '<:encoding(UTF-8)', "tools/service-pages.$l.json"
        or die "falta tools/service-pages.$l.json\n";
    local $/;
    $data{$l} = JSON::PP->new->decode(<$f>);
    close $f;
    $slug{$l}{ $_->{id} } = $_->{slug} for @{ $data{$l}{pages} };
}

sub esc {
    my $s = shift // '';
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    return $s;
}

# Cabecera y pie del index del idioma, adaptados a una subpagina.
sub shell_for {
    my ($lang, $dir, $page) = @_;
    open my $f, '<:encoding(UTF-8)', "${dir}index.html" or die "falta ${dir}index.html\n";
    local $/;
    my $src = <$f>;
    close $f;

    my ($head) = $src =~ m{(<a class="skip-link".*?)(?=  <main)}s or die "sin cabecera en $lang\n";
    my ($foot) = $src =~ m{(<footer class="footer".*?</footer>)}s  or die "sin pie en $lang\n";

    for ($head, $foot) {
        s{href="#top"}{href="index.html"}g;
        s{href="#([a-z0-9-]+)"}{href="index.html#$1"}g;
    }

    my %path = (
        es => ($lang eq 'es' ? '' : '../') . ($slug{es}{ $page->{id} } || 'index.html'),
        en => ($lang eq 'en' ? '' : ($lang eq 'es' ? 'en/' : '../en/')) . ($slug{en}{ $page->{id} } || 'index.html'),
        fr => ($lang eq 'fr' ? '' : ($lang eq 'es' ? 'fr/' : '../fr/')) . ($slug{fr}{ $page->{id} } || 'index.html'),
    );
    my $sep = '<span class="lang-switch-sep">&#183;</span>';
    my $switch = join $sep, map {
        my $u = uc $_;
        $_ eq $lang
            ? qq{<span class="lang-current">$u</span>}
            : qq{<a href="$path{$_}">$u</a>};
    } qw(es en fr);

    for ($head, $foot) {
        s{(<div class="lang-switch[^"]*"[^>]*>)\s*.*?\s*(</div>)}{$1\n        $switch\n      $2}s;
    }
    return ($head, $foot);
}

for my $lang (@langs) {
    my $d    = $data{$lang};
    my $dir  = $d->{dir};
    my $L    = $d->{labels};
    my $up   = $dir eq '' ? '' : '../';
    my $base = 'https://benamar.es/';

    for my $p (@{ $d->{pages} }) {
        my ($head, $foot) = shell_for($lang, $dir, $p);

        my %alt = (
            es => $base . ($slug{es}{ $p->{id} } || ''),
            en => $base . 'en/' . ($slug{en}{ $p->{id} } || ''),
            fr => $base . 'fr/' . ($slug{fr}{ $p->{id} } || ''),
        );
        my $canonical = $alt{$lang};

        my $hreflang = join "\n",
            map { qq{  <link rel="alternate" hreflang="$_" href="$alt{$_}">} }
            grep { $slug{$_}{ $p->{id} } } qw(es en fr);
        $hreflang .= qq{\n  <link rel="alternate" hreflang="x-default" href="$alt{es}">};

        my $includes = join "\n", map {
                  qq{        <div class="benefit" data-reveal>\n}
                . qq{          <h3>} . esc($_->{h}) . qq{</h3>\n}
                . qq{          <p>} . esc($_->{p}) . qq{</p>\n}
                . qq{        </div>}
        } @{ $p->{includes} };

        my $process = join "\n", map {
                  qq{        <li data-reveal>\n}
                . qq{          <h3>} . esc($_->{h}) . qq{</h3>\n}
                . qq{          <p>} . esc($_->{p}) . qq{</p>\n}
                . qq{        </li>}
        } @{ $p->{process} };

        my $audience = join "\n",
            map { qq{        <li data-reveal>} . esc($_) . qq{</li>} } @{ $p->{audience} };

        my $faq = join "\n", map {
                  qq{        <div class="faq-item" data-reveal>\n}
                . qq{          <h3>} . esc($_->{q}) . qq{</h3>\n}
                . qq{          <p>} . esc($_->{a}) . qq{</p>\n}
                . qq{        </div>}
        } @{ $p->{faq} };

        my $others = join "\n",
            map { qq{        <a class="other-service" href="$_->{slug}" data-reveal>} . esc($_->{h1}) . qq{</a>} }
            grep { $_->{id} ne $p->{id} } @{ $d->{pages} };

        my $intro = join "\n",
            map { qq{      <p class="about-body" data-reveal>} . esc($_) . qq{</p>} } @{ $p->{intro} };

        my $ld = JSON::PP->new->canonical->pretty->encode({
            '@context' => 'https://schema.org',
            '@graph'   => [
                {   '@type'       => 'Service',
                    'name'        => $p->{h1},
                    'serviceType' => $p->{h1},
                    'description' => $p->{description},
                    'url'         => $canonical,
                    'areaServed'  => [ { '@type' => 'City', 'name' => 'Barcelona' }, { '@type' => 'Country', 'name' => 'España' } ],
                    'provider'    => { '@id' => 'https://benamar.es/#organization' },
                },
                {   '@type'      => 'FAQPage',
                    'mainEntity' => [
                        map { {
                            '@type'          => 'Question',
                            'name'           => $_->{q},
                            'acceptedAnswer' => { '@type' => 'Answer', 'text' => $_->{a} },
                        } } @{ $p->{faq} }
                    ],
                },
            ],
        });
        $ld =~ s/^/  /mg;

        my $title = esc($p->{title});
        my $desc  = esc($p->{description});
        my $fonts = 'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=Fraunces:ital,opsz,wght@1,9..144,300..700&display=swap';

        my $html = <<"HTML";
<!doctype html>
<html lang="$lang">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$title</title>
  <meta name="description" content="$desc">
  <link rel="canonical" href="$canonical">
$hreflang
  <meta property="og:type" content="website">
  <meta property="og:title" content="$title">
  <meta property="og:description" content="$desc">
  <meta property="og:url" content="$canonical">
  <meta property="og:image" content="${base}assets/img/hero-agency.jpg">
  <link rel="icon" href="${up}assets/favicon.svg" type="image/svg+xml">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="$fonts">
  <link rel="stylesheet" href="${up}styles.css?v=20260920">
  <script type="application/ld+json">
$ld  </script>
</head>
<body>
  $head<main id="main">
    <section class="service-tile $p->{tile} page-hero">
      <p class="service-num">@{[ esc($L->{kicker}) ]}</p>
      <h1 class="service-title">@{[ esc($p->{h1}) ]}</h1>
      <p class="service-teaser">@{[ esc($p->{teaser}) ]}</p>
      <div class="service-actions">
        <a class="link-more" href="index.html#servicios">@{[ esc($L->{backToServices}) ]} &rsaquo;</a>
        <a class="btn btn-primary btn-sm" href="index.html#contacto">@{[ esc($L->{ctaButton}) ]}</a>
      </div>
    </section>

    <section class="about">
$intro
    </section>

    <section class="manifesto">
      <h2 class="manifesto-statement" data-reveal>@{[ esc($L->{includes}) ]}</h2>
      <div class="benefits-grid benefits-grid--4">
$includes
      </div>
    </section>

    <section class="service-section">
      <h2 data-reveal>@{[ esc($L->{process}) ]}</h2>
      <ol class="process">
$process
      </ol>
    </section>

    <section class="service-section">
      <h2 data-reveal>@{[ esc($L->{audience}) ]}</h2>
      <ul class="audience">
$audience
      </ul>
    </section>

    <section class="service-section">
      <h2 data-reveal>@{[ esc($L->{faq}) ]}</h2>
      <div class="faq">
$faq
      </div>
    </section>

    <section class="cta-band">
      <h2 class="cta-band-heading" data-reveal>@{[ esc($L->{ctaHeading}) ]}</h2>
      <p class="cta-band-sub" data-reveal>@{[ esc($L->{ctaSub}) ]}</p>
      <a class="btn btn-primary" href="index.html#contacto" data-reveal>@{[ esc($L->{ctaButton}) ]}</a>
    </section>

    <section class="service-section">
      <h2 data-reveal>@{[ esc($L->{others}) ]}</h2>
      <div class="other-services">
$others
      </div>
    </section>
  </main>

  $foot

  <script defer src="${up}main.js?v=20260920"></script>
</body>
</html>
HTML

        open my $out, '>:encoding(UTF-8)', "$dir$p->{slug}" or die "no puedo escribir $dir$p->{slug}\n";
        print $out $html;
        close $out;
        printf "%-52s %s\n", "$dir$p->{slug}", 'generada';
    }
}
