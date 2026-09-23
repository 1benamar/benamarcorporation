#!/usr/bin/perl
# Genera las paginas de servicio a partir de los JSON de contenido.
# La cabecera y el pie se copian del index de cada idioma para que no se
# desincronicen; solo se reescriben los enlaces que cambian en una subpagina.
use strict;
use warnings;
use utf8;
use JSON::PP;
binmode(STDOUT, ':encoding(UTF-8)');

my @langs = @ARGV ? @ARGV : qw(es en fr);
my (%data, %slug);

for my $l (@langs) {
    open my $f, '<:encoding(UTF-8)', "tools/service-pages.$l.json"
        or die "falta tools/service-pages.$l.json\n";
    local $/;
    $data{$l} = JSON::PP->new->decode(<$f>);
    close $f;
    $slug{$l}{ $_->{id} } = $_->{slug} for @{ $data{$l}{pages} };
}

# Iconos de linea, del mismo trazo que los de la portada.
my %ICON = (
    layout   => '<rect x="3" y="4" width="18" height="16" rx="2"></rect><path d="M3 9h18M9 9v11"></path>',
    code     => '<path d="M8 6l-5 6 5 6M16 6l5 6-5 6"></path>',
    type     => '<path d="M5 6h14M12 6v12M9 18h6"></path>',
    search   => '<circle cx="11" cy="11" r="6"></circle><path d="M20 20l-4.5-4.5"></path>',
    target   => '<circle cx="12" cy="12" r="8"></circle><circle cx="12" cy="12" r="3"></circle>',
    layers   => '<path d="M12 3l9 5-9 5-9-5 9-5z"></path><path d="M3 14l9 5 9-5"></path>',
    mail     => '<rect x="3" y="5" width="18" height="14" rx="2"></rect><path d="M3 7l9 6 9-6"></path>',
    chart    => '<path d="M4 20V10M10 20V4M16 20v-7"></path>',
    calendar => '<rect x="3" y="5" width="18" height="16" rx="2"></rect><path d="M3 10h18M8 3v4M16 3v4"></path>',
    image    => '<rect x="3" y="5" width="18" height="14" rx="2"></rect><circle cx="8.5" cy="10" r="1.5"></circle><path d="M21 16l-5-5-6 6"></path>',
    message  => '<path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.2A8 8 0 1 1 21 12z"></path>',
    pin      => '<path d="M12 21s7-6 7-11a7 7 0 1 0-14 0c0 5 7 11 7 11z"></path><circle cx="12" cy="10" r="2.5"></circle>',
    tag      => '<path d="M20 12l-8 8-8-8V4h8l8 8z"></path><circle cx="8.5" cy="8.5" r="1.5"></circle>',
    clock    => '<circle cx="12" cy="12" r="8"></circle><path d="M12 8v4l3 2"></path>',
    user     => '<circle cx="12" cy="8" r="3.5"></circle><path d="M5 20c0-3.5 3.1-6 7-6s7 2.5 7 6"></path>',
    unlock   => '<rect x="5" y="11" width="14" height="9" rx="2"></rect><path d="M8 11V8a4 4 0 0 1 7-2.6"></path>',
);

sub icon {
    my ($name, $class) = @_;
    my $paths = $ICON{ $name // '' } or return '';
    return qq{<svg class="$class" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">$paths</svg>};
}

# Lee el tamaño real de un JPEG en su cabecera, para reservarle el hueco.
sub dims {
    my $name = shift;
    open my $fh, '<:raw', "assets/img/$name.jpg" or die "falta la foto $name\n";
    my $d = do { local $/; <$fh> }; close $fh;
    my $i = 2;
    while ($i < length($d) - 8) {
        last unless ord(substr($d,$i,1)) == 0xFF;
        my $m = ord(substr($d,$i+1,1));
        my $len = unpack('n', substr($d,$i+2,2));
        if ($m >= 0xC0 && $m <= 0xCF && $m != 0xC4 && $m != 0xC8 && $m != 0xCC) {
            return (unpack('n', substr($d,$i+7,2)), unpack('n', substr($d,$i+5,2)));
        }
        $i += 2 + $len;
    }
    die "no leo el tamaño de $name\n";
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
# Artículos que enlazan a este servicio: la página de servicio los enlaza
# de vuelta, para que los enlaces vayan en los dos sentidos.
sub articulos_de {
    my ($lang, $ruta) = @_;
    my $jf = "tools/articulos.$lang.json";
    return () unless -f $jf;
    open my $h, '<:encoding(UTF-8)', $jf or die; local $/; my $x = JSON::PP->new->decode(<$h>); close $h;
    my @r = grep { !$_->{draft} && grep { $_->{href} eq $ruta } @{ $_->{related} || [] } } @{ $x->{articles} };
    @r = sort { $b->{date} cmp $a->{date} } @r;
    $_->{url} = "/$x->{dir}$x->{section}/$_->{slug}.html" for @r;
    $_->{readMore} = $x->{labels}{readMore} for @r;
    return @r[0 .. ($#r < 1 ? $#r : 1)];
}

sub shell_for {
    my ($lang, $dir, $page) = @_;
    open my $f, '<:encoding(UTF-8)', "${dir}index.html" or die "falta ${dir}index.html\n";
    local $/;
    my $src = <$f>;
    close $f;

    my ($head) = $src =~ m{(<a class="skip-link".*?)(?=  <main)}s or die "sin cabecera en $lang\n";
    my ($foot) = $src =~ m{(<footer class="footer".*?</footer>)}s  or die "sin pie en $lang\n";

    # La portada de cada idioma, en su forma canónica.
    my $home = "/$dir";

    for ($head, $foot) {
        s{href="#top"}{href="$home"}g;
        s{href="#([a-z0-9-]+)"}{href="$home#$1"}g;
        # El enlace de salto lleva al contenido de esta página, no al de la portada.
        s{(<a class="skip-link" href=")[^"]*(")}{${1}#main$2};
    }

    my %path = (
        es => $slug{es}{ $page->{id} } ? '/'    . $slug{es}{ $page->{id} } : '/',
        en => $slug{en}{ $page->{id} } ? '/en/' . $slug{en}{ $page->{id} } : '/en/',
        fr => $slug{fr}{ $page->{id} } ? '/fr/' . $slug{fr}{ $page->{id} } : '/fr/',
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
        my $home_url  = 'https://benamar.es/' . ($lang eq 'es' ? '' : "$lang/");

        my $hreflang = join "\n",
            map { qq{  <link rel="alternate" hreflang="$_" href="$alt{$_}">} }
            grep { $slug{$_}{ $p->{id} } } qw(es en fr);
        $hreflang .= qq{\n  <link rel="alternate" hreflang="x-default" href="$alt{es}">};

        my $includes = join "\n", map {
                  qq{        <div class="benefit" data-reveal>\n}
                . qq{          <div class="benefit-head">} . icon($_->{icon}, 'benefit-icon') . qq{</div>\n}
                . qq{          <h3>} . esc($_->{h}) . qq{</h3>\n}
                . qq{          <p>} . esc($_->{p}) . qq{</p>\n}
                . qq{        </div>}
        } @{ $p->{includes} };

        # Franja de cifras, distinta en cada servicio.
        my $stats = join "\n", map {
                  qq{        <div class="stat" data-reveal>\n}
                . qq{          } . icon($_->{i}, 'stat-icon') . qq{\n}
                . qq{          <span class="stat-value">$_->{v}</span>\n}
                . qq{          <span class="stat-label">} . esc($_->{l}) . qq{</span>\n}
                . qq{        </div>}
        } @{ $p->{stats} };

        my $process = join "\n", map {
                  qq{        <li data-reveal>\n}
                . qq{          <h3>} . esc($_->{h}) . qq{</h3>\n}
                . qq{          <p>} . esc($_->{p}) . qq{</p>\n}
                . qq{        </li>}
        } @{ $p->{process} };

        my $audience = join "\n", map {
                  qq{        <div class="audience-item" data-reveal>\n}
                . qq{          <dt>} . esc($_->{who}) . qq{</dt>\n}
                . qq{          <dd>} . esc($_->{why}) . qq{</dd>\n}
                . qq{        </div>}
        } @{ $p->{audience} };

        my $n_faq = 0;
        my $faq = join "\n", map {
                  my $open = $n_faq++ ? '' : ' open';
                  qq{        <details class="faq-item" data-reveal$open>\n}
                . qq{          <summary><h3>} . esc($_->{q}) . qq{</h3><span class="faq-sign" aria-hidden="true"></span></summary>\n}
                . qq{          <div class="faq-answer"><p>} . esc($_->{a}) . qq{</p></div>\n}
                . qq{        </details>}
        } @{ $p->{faq} };

        # Cada servicio relacionado se presenta con su propia fotografia.
        # Artículos relacionados con este servicio.
        my $ruta = '/' . $dir . $p->{slug};
        my @arts = articulos_de($lang, $ruta);
        my $articulos = '';
        if (@arts) {
            my $items = join "\n", map {
                my ($aw, $ah) = dims($_->{image});
                (my $t = $_->{h1}) =~ s/\*//g;
                  qq{        <li class="post-item" data-reveal>\n}
                . qq{          <a class="post-card" href="$_->{url}">\n}
                . qq{            <img class="post-card-photo" src="${up}assets/img/$_->{image}.jpg" alt="} . esc($_->{imageAlt}) . qq{" width="$aw" height="$ah" loading="lazy" decoding="async">\n}
                . qq{            <span class="post-card-text">\n}
                . qq{              <h3 class="post-card-title">} . esc($t) . qq{</h3>\n}
                . qq{              <span class="post-card-excerpt">} . esc($_->{excerpt}) . qq{</span>\n}
                . qq{              <span class="link-more">} . esc($_->{readMore}) . qq{ &rsaquo;</span>\n}
                . qq{            </span>\n}
                . qq{          </a>\n}
                . qq{        </li>}
            } @arts;
            $articulos = qq{    <section class="service-section">\n}
                       . qq{      <h2 data-reveal>} . esc($L->{relatedArticles}) . qq{</h2>\n}
                       . qq{      <p class="section-deck" data-reveal>} . esc($L->{relatedDeck}) . qq{</p>\n}
                       . qq{      <ol class="post-list">\n$items\n      </ol>\n}
                       . qq{    </section>\n\n};
        }

        my $others = join "\n",
            map {
                  qq{        <a class="other-service" href="$_->{slug}" data-reveal>\n}
                . do { my ($ow,$oh) = dims($_->{heroImage});
                       qq{          <img class="other-service-photo" src="${up}assets/img/$_->{heroImage}.jpg" alt="} . esc($_->{heroAlt}) . qq{" width="$ow" height="$oh" loading="lazy" decoding="async">\n} }
                . qq{          <span class="other-service-name">} . esc($_->{h1}) . qq{</span>\n}
                . qq{        </a>}
            }
            grep { $_->{id} ne $p->{id} } @{ $d->{pages} };

        # Una frase de cada texto enlaza al servicio del que habla.
        my %enlace = map { $_->{text} => $slug{$lang}{ $_->{to} } } @{ $p->{links} || [] };
        my $intro = join "\n", map {
            my $t = esc($_);
            for my $frase (sort { length($b) <=> length($a) } keys %enlace) {
                my $e = esc($frase);
                $t =~ s{\Q$e\E}{<a href="$enlace{$frase}">$e</a>};
            }
            qq{      <p class="about-body" data-reveal>$t</p>}
        } @{ $p->{intro} };

        my $ld = JSON::PP->new->canonical->pretty->encode({
            '@context' => 'https://schema.org',
            '@graph'   => [
                {   '@type'            => 'BreadcrumbList',
                    'itemListElement'  => [
                        { '@type' => 'ListItem', 'position' => 1, 'name' => $L->{home}, 'item' => $home_url },
                        { '@type' => 'ListItem', 'position' => 2, 'name' => $p->{h1},   'item' => $canonical },
                    ],
                },
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

        my $home = "/$dir";
        my $og_locale = { es => 'es_ES', en => 'en_GB', fr => 'fr_FR' }->{$lang};
        my ($pw, $ph) = dims($p->{photo});
        my ($hw, $hh) = dims($p->{heroImage});
        my $title = esc($p->{title});
        my $desc  = esc($p->{description});

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
  <meta property="og:image" content="${base}assets/img/$p->{heroImage}.jpg">
  <meta property="og:image:width" content="$hw">
  <meta property="og:image:height" content="$hh">
  <meta property="og:image:alt" content="@{[ esc($p->{heroAlt}) ]}">
  <meta property="og:locale" content="$og_locale">
  <meta property="og:site_name" content="BENAMAR">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="$title">
  <meta name="twitter:description" content="$desc">
  <meta name="twitter:image" content="${base}assets/img/$p->{heroImage}.jpg">
  <link rel="preload" as="image" href="${up}assets/img/$p->{heroImage}.jpg" fetchpriority="high">
  <link rel="icon" href="/favicon.ico" sizes="48x48">
  <link rel="icon" href="/assets/favicon.svg" type="image/svg+xml">
  <link rel="icon" href="/assets/favicon-96.png" type="image/png" sizes="96x96">
  <link rel="icon" href="/assets/favicon-192.png" type="image/png" sizes="192x192">
  <link rel="apple-touch-icon" href="/assets/apple-touch-icon.png">
  <link rel="preload" as="font" type="font/woff2" href="${up}assets/fonts/inter-latin.woff2" crossorigin>
  <link rel="stylesheet" href="${up}styles.css?v=20260923c">
  <script type="application/ld+json">
$ld  </script>
</head>
<body>
  $head<main id="main">
    <section class="service-tile $p->{tile} page-hero">
      <img class="tile-photo" src="${up}assets/img/$p->{heroImage}.jpg" alt="@{[ esc($p->{heroAlt}) ]}" width="$hw" height="$hh" fetchpriority="high" decoding="async">
      <h1 class="service-title">@{[ esc($p->{h1}) ]}</h1>
      <p class="service-teaser">@{[ esc($p->{teaser}) ]}</p>
      <div class="service-actions">
        <a class="link-more" href="${home}#servicios">@{[ esc($L->{backToServices}) ]} &rsaquo;</a>
        <a class="btn btn-primary btn-sm" href="${home}#contacto">@{[ esc($L->{ctaButton}) ]}</a>
      </div>
    </section>

    <nav class="breadcrumb" aria-label="@{[ esc($L->{breadcrumb}) ]}">
      <ol>
        <li><a href="$home">@{[ esc($L->{home}) ]}</a></li>
        <li><span aria-current="page">@{[ esc($p->{h1}) ]}</span></li>
      </ol>
    </nav>

    <section class="about">
      <p class="service-lead" data-reveal>@{[ esc($p->{lead}) ]}</p>
$intro
      <p class="kicker stats-kicker" data-reveal>@{[ esc($L->{figures}) ]}</p>
      <div class="stats-grid">
$stats
      </div>
    </section>

    <section class="manifesto">
      <h2 class="manifesto-statement" data-reveal>@{[ esc($L->{includes}) ]}</h2>
      <p class="section-deck" data-reveal>@{[ esc($L->{deck}{includes}) ]}</p>
      <div class="benefits-grid benefits-grid--4">
$includes
      </div>
    </section>

    <section class="service-process">
      <div class="service-process-inner">
        <div class="service-process-photo" data-reveal>
          <img class="service-photo" src="${up}assets/img/$p->{photo}.jpg" alt="@{[ esc($p->{photoAlt}) ]}" width="$pw" height="$ph" loading="lazy" decoding="async">
        </div>
        <div class="service-process-text">
          <h2 data-reveal>@{[ esc($L->{process}) ]}</h2>
      <p class="section-deck" data-reveal>@{[ esc($L->{deck}{process}) ]}</p>
          <ol class="process">
$process
          </ol>
        </div>
      </div>
    </section>

    <section class="service-band" data-reveal>
      <p class="service-band-line">@{[ esc($L->{band}) ]}</p>
    </section>

    <section class="service-section">
      <h2 data-reveal>@{[ esc($L->{audience}) ]}</h2>
      <p class="section-deck" data-reveal>@{[ esc($L->{deck}{audience}) ]}</p>
      <dl class="audience">
$audience
      </dl>
    </section>

    <section class="service-section">
      <h2 data-reveal>@{[ esc($L->{faq}) ]}</h2>
      <p class="section-deck" data-reveal>@{[ esc($L->{deck}{faq}) ]}</p>
      <div class="faq">
$faq
      </div>
    </section>

$articulos    <section class="cta-band">
      <h2 class="cta-band-heading" data-reveal>@{[ esc($L->{ctaHeading}) ]}</h2>
      <p class="cta-band-sub" data-reveal>@{[ esc($L->{ctaSub}) ]}</p>
      <a class="btn btn-primary" href="${home}#contacto" data-reveal>@{[ esc($L->{ctaButton}) ]}</a>
    </section>

    <section class="service-section">
      <h2 data-reveal>@{[ esc($L->{others}) ]}</h2>
      <p class="section-deck" data-reveal>@{[ esc($L->{deck}{others}) ]}</p>
      <div class="other-services">
$others
      </div>
    </section>
  </main>

  $foot

  <script defer src="${up}main.js?v=20260923b"></script>
</body>
</html>
HTML

        open my $out, '>:encoding(UTF-8)', "$dir$p->{slug}" or die "no puedo escribir $dir$p->{slug}\n";
        print $out $html;
        close $out;
        printf "%-52s %s\n", "$dir$p->{slug}", 'generada';
    }
}
