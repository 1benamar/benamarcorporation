#!/usr/bin/perl
# Genera la sección de artículos a partir de tools/articulos.<idioma>.json
# y de los cuerpos en tools/articulos/<idioma>/<slug>.html.
#
#   perl tools/build-articles.pl          # todos los idiomas con archivo de datos
#   perl tools/build-articles.pl es       # solo español
#
# Escribe <seccion>/index.html, una página por artículo, y actualiza el
# bloque de artículos del sitemap.xml. La cabecera y el pie se copian de la
# portada de cada idioma, así que nunca se quedan desfasados.
use strict;
use warnings;
use utf8;
use JSON::PP;
use POSIX qw(ceil);
binmode(STDOUT, ':encoding(UTF-8)');

my $BASE  = 'https://benamar.es';
my @langs = @ARGV ? @ARGV : grep { -f "tools/articulos.$_.json" } qw(es en fr);
die "no hay ningún archivo de artículos\n" unless @langs;

# Mismas versiones de estilos y script que la portada, para la caché.
my ($CSSV, $JSV) = do {
    open my $f, '<:encoding(UTF-8)', 'index.html' or die "falta index.html\n";
    local $/; my $t = <$f>; close $f;
    my ($c) = $t =~ /styles\.css\?v=([0-9a-z]+)/;
    my ($j) = $t =~ /main\.js\?v=([0-9a-z]+)/;
    ($c, $j);
};

sub esc {
    my $s = shift // '';
    $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; $s =~ s/"/&quot;/g;
    return $s;
}

# Tamaño real de un JPEG, leído de su cabecera, para reservar el hueco.
sub dims {
    my $name = shift;
    open my $fh, '<:raw', "assets/img/$name.jpg" or die "falta la foto $name\n";
    my $d = do { local $/; <$fh> }; close $fh;
    my $i = 2;
    while ($i < length($d) - 8) {
        last unless ord(substr($d, $i, 1)) == 0xFF;
        my $m   = ord(substr($d, $i + 1, 1));
        my $len = unpack('n', substr($d, $i + 2, 2));
        if ($m >= 0xC0 && $m <= 0xCF && $m != 0xC4 && $m != 0xC8 && $m != 0xCC) {
            return (unpack('n', substr($d, $i + 7, 2)), unpack('n', substr($d, $i + 5, 2)));
        }
        $i += 2 + $len;
    }
    die "no leo el tamaño de $name\n";
}

sub fecha {
    my ($iso, $L) = @_;
    my ($y, $m, $d) = split /-/, $iso;
    my $s = $L->{dateFormat};
    my $mes = $L->{months}[$m - 1];
    $s =~ s/%d/int($d)/e;
    $s =~ s/%m/$mes/;
    $s =~ s/%y/$y/;
    return $s;
}

sub palabras {
    my $html = shift;
    (my $t = $html) =~ s/<[^>]+>/ /g;
    my @w = grep { length } split /\s+/, $t;
    return scalar @w;
}

# Cabecera y pie de la portada del idioma, con todos los enlaces convertidos
# en rutas desde la raíz: la sección vive en una subcarpeta.
sub shell {
    my ($dir, $section) = @_;
    open my $f, '<:encoding(UTF-8)', "${dir}index.html" or die "falta ${dir}index.html\n";
    local $/; my $src = <$f>; close $f;

    my ($head) = $src =~ m{(<a class="skip-link".*?)(?=  <main)}s or die "sin cabecera en ${dir}index.html\n";
    my ($foot) = $src =~ m{(<footer class="footer".*?</footer>)}s  or die "sin pie en ${dir}index.html\n";
    my $home = "/$dir";

    for ($head, $foot) {
        s{href="#top"}{href="$home"}g;
        s{href="#([a-z0-9-]+)"}{href="$home#$1"}g;
        # El enlace de salto lleva al contenido de esta página.
        s{(<a class="skip-link" href=")[^"]*(")}{${1}#main$2};
        # Enlaces relativos, como los de las páginas legales.
        s{href="(?!/|#|https?:|mailto:|tel:)([^"]+)"}{href="/$dir$1"}g;
        # La sección actual, marcada en el menú.
        s{(<a class="nav-link" href="/\Q$dir$section\E/")}{$1 aria-current="page"}g;
    }
    return ($head, $foot);
}

sub cabeza {
    my (%a) = @_;
    my $ld = join '', map {
        my $j = JSON::PP->new->canonical->pretty->encode($_);
        $j =~ s/^/  /mg;
        qq{  <script type="application/ld+json">\n$j  </script>\n}
    } @{ $a{ld} };

    my $art = '';
    if ($a{published}) {
        $art = qq{  <meta property="article:published_time" content="$a{published}">\n}
             . qq{  <meta property="article:modified_time" content="$a{modified}">\n};
    }

    return <<"HTML";
<!doctype html>
<html lang="$a{lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>@{[ esc($a{title}) ]}</title>
  <meta name="description" content="@{[ esc($a{description}) ]}">
  <link rel="canonical" href="$a{canonical}">
  <meta property="og:type" content="$a{ogtype}">
  <meta property="og:site_name" content="BENAMAR">
  <meta property="og:locale" content="$a{locale}">
  <meta property="og:title" content="@{[ esc($a{title}) ]}">
  <meta property="og:description" content="@{[ esc($a{description}) ]}">
  <meta property="og:url" content="$a{canonical}">
  <meta property="og:image" content="$BASE/assets/img/$a{image}.jpg">
  <meta property="og:image:width" content="$a{w}">
  <meta property="og:image:height" content="$a{h}">
  <meta property="og:image:alt" content="@{[ esc($a{imageAlt}) ]}">
$art  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="@{[ esc($a{title}) ]}">
  <meta name="twitter:description" content="@{[ esc($a{description}) ]}">
  <meta name="twitter:image" content="$BASE/assets/img/$a{image}.jpg">
  <link rel="icon" href="/favicon.ico" sizes="48x48">
  <link rel="icon" href="/assets/favicon.svg" type="image/svg+xml">
  <link rel="icon" href="/assets/favicon-96.png" type="image/png" sizes="96x96">
  <link rel="icon" href="/assets/favicon-192.png" type="image/png" sizes="192x192">
  <link rel="apple-touch-icon" href="/assets/apple-touch-icon.png">
  <link rel="preload" as="font" type="font/woff2" href="/assets/fonts/inter-latin.woff2" crossorigin>
  <link rel="stylesheet" href="/styles.css?v=$CSSV">
  <noscript><style>[data-reveal]{opacity:1!important;transform:none!important;}</style></noscript>
$ld</head>
HTML
}

sub cta {
    my $L = shift;
    my $dir = shift;
    return <<"HTML";
    <section class="cta-band">
      <h2 class="cta-band-heading" data-reveal>@{[ esc($L->{ctaHeading}) ]}</h2>
      <p class="cta-band-sub" data-reveal>@{[ esc($L->{ctaSub}) ]}</p>
      <a class="btn btn-primary" href="/$dir#contacto" data-reveal>@{[ esc($L->{ctaButton}) ]}</a>
    </section>
HTML
}

sub tarjeta {
    my ($p, $L, $sec_url, $tag) = @_;
    my ($w, $h) = dims($p->{image});
    return qq{        <li class="post-item" data-reveal>\n}
         . qq{          <a class="post-card" href="$sec_url$p->{slug}.html">\n}
         . qq{            <img class="post-card-photo" src="/assets/img/$p->{image}.jpg" alt="@{[ esc($p->{imageAlt}) ]}" width="$w" height="$h" loading="lazy" decoding="async">\n}
         . qq{            <span class="post-card-text">\n}
         . qq{              <$tag class="post-card-title">@{[ esc($p->{h1}) ]}</$tag>\n}
         . qq{              <span class="post-card-excerpt">@{[ esc($p->{excerpt}) ]}</span>\n}
         . qq{              <span class="post-meta"><time datetime="$p->{date}">@{[ fecha($p->{date}, $L) ]}</time><span class="post-meta-sep" aria-hidden="true">·</span>$p->{minutes} @{[ esc($L->{minutes}) ]}</span>\n}
         . qq{              <span class="link-more">@{[ esc($L->{readMore}) ]} &rsaquo;</span>\n}
         . qq{            </span>\n}
         . qq{          </a>\n}
         . qq{        </li>};
}

sub escribe {
    my ($ruta, $html) = @_;
    open my $o, '>:encoding(UTF-8)', $ruta or die "no puedo escribir $ruta\n";
    print $o $html; close $o;
    printf "%-52s generada\n", $ruta;
}

my @mapa;   # direcciones para el sitemap

for my $lang (@langs) {
    open my $jf, '<:encoding(UTF-8)', "tools/articulos.$lang.json" or die;
    local $/; my $d = JSON::PP->new->decode(<$jf>); close $jf;
    my $L       = $d->{labels};
    my $dir     = $d->{dir};
    my $section = $d->{section};
    my $sec_url = "/$dir$section/";
    my $sec_abs = "$BASE$sec_url";
    my $home    = "$BASE/$dir";
    mkdir "$dir$section" unless -d "$dir$section";

    my ($head, $foot) = shell($dir, $section);
    my $publisher = {
        '@type' => 'Organization', '@id' => "$BASE/#organization", 'name' => 'BENAMAR',
        'logo'  => { '@type' => 'ImageObject', 'url' => "$BASE/assets/favicon-192.png" },
    };

    # Solo los artículos terminados, del más reciente al más antiguo.
    my @arts = sort { $b->{date} cmp $a->{date} } grep { !$_->{draft} } @{ $d->{articles} };
    for my $p (@arts) {
        my $f = "tools/articulos/$lang/$p->{slug}.html";
        open my $bf, '<:encoding(UTF-8)', $f or die "falta el cuerpo $f\n";
        local $/; $p->{body} = <$bf>; close $bf;
        $p->{words}   = palabras($p->{body});
        $p->{minutes} = ceil($p->{words} / 200) || 1;
    }

    # ---------- Cada artículo ----------
    for my $p (@arts) {
        my $url = "$sec_abs$p->{slug}.html";
        my ($w, $h) = dims($p->{image});

        my $ld = [{
            '@context' => 'https://schema.org',
            '@graph'   => [
                {   '@type' => 'BreadcrumbList',
                    'itemListElement' => [
                        { '@type' => 'ListItem', 'position' => 1, 'name' => $L->{home},    'item' => $home },
                        { '@type' => 'ListItem', 'position' => 2, 'name' => $L->{section}, 'item' => $sec_abs },
                        { '@type' => 'ListItem', 'position' => 3, 'name' => $p->{h1},      'item' => $url },
                    ],
                },
                {   '@type'            => 'BlogPosting',
                    'headline'         => $p->{h1},
                    'description'      => $p->{description},
                    'image'            => ["$BASE/assets/img/$p->{image}.jpg"],
                    'datePublished'    => $p->{date},
                    'dateModified'     => $p->{updated} || $p->{date},
                    'inLanguage'       => $lang,
                    'wordCount'        => $p->{words},
                    'url'              => $url,
                    'mainEntityOfPage' => $url,
                    'author'           => { '@type' => 'Organization', 'name' => 'BENAMAR', 'url' => "$BASE/" },
                    'publisher'        => $publisher,
                },
            ],
        }];

        my $rel = '';
        if ($p->{related} && @{ $p->{related} }) {
            $rel = qq{      <aside class="post-related" aria-label="@{[ esc($L->{related}) ]}">\n}
                 . qq{        <p class="post-related-title">@{[ esc($L->{related}) ]}</p>\n}
                 . qq{        <ul>\n}
                 . join('', map { qq{          <li><a href="$_->{href}">@{[ esc($_->{name}) ]} &rsaquo;</a></li>\n} } @{ $p->{related} })
                 . qq{        </ul>\n}
                 . qq{      </aside>\n};
        }

        # Hasta tres artículos más, si los hay.
        my @otros = grep { $_->{slug} ne $p->{slug} } @arts;
        my $mas = '';
        if (@otros) {
            @otros = @otros[0 .. ($#otros < 2 ? $#otros : 2)];
            $mas = qq{    <section class="service-section">\n}
                 . qq{      <h2 data-reveal>@{[ esc($L->{section}) ]}</h2>\n}
                 . qq{      <ol class="post-list">\n}
                 . join("\n", map { tarjeta($_, $L, $sec_url, 'h3') } @otros)
                 . qq{\n      </ol>\n}
                 . qq{    </section>\n\n};
        }

        (my $body = $p->{body}) =~ s/^/      /mg;
        $body =~ s/^\s+$//mg;

        my $html = cabeza(
            lang => $lang, locale => $d->{locale}, title => $p->{title}, description => $p->{description},
            canonical => $url, ogtype => 'article', image => $p->{image}, imageAlt => $p->{imageAlt},
            w => $w, h => $h, ld => $ld, published => $p->{date}, modified => $p->{updated} || $p->{date},
        ) . <<"HTML";
<body>
  $head<main id="main" class="post-main">
    <nav class="breadcrumb breadcrumb--top" aria-label="@{[ esc($L->{breadcrumb}) ]}">
      <ol>
        <li><a href="/$dir">@{[ esc($L->{home}) ]}</a></li>
        <li><a href="$sec_url">@{[ esc($L->{section}) ]}</a></li>
        <li><span aria-current="page">@{[ esc($p->{h1}) ]}</span></li>
      </ol>
    </nav>

    <article class="post">
      <header class="post-header">
        <h1 class="post-title">@{[ esc($p->{h1}) ]}</h1>
        <p class="post-lead">@{[ esc($p->{excerpt}) ]}</p>
        <p class="post-meta"><time datetime="$p->{date}">@{[ fecha($p->{date}, $L) ]}</time><span class="post-meta-sep" aria-hidden="true">·</span>$p->{minutes} @{[ esc($L->{minutes}) ]}</p>
      </header>

      <figure class="post-figure">
        <img src="/assets/img/$p->{image}.jpg" alt="@{[ esc($p->{imageAlt}) ]}" width="$w" height="$h" fetchpriority="high" decoding="async">
      </figure>

      <div class="post-body">
$body      </div>

$rel    </article>

@{[ cta($L, $dir) ]}
$mas  </main>

  $foot

  <script defer src="/main.js?v=$JSV"></script>
</body>
</html>
HTML
        escribe("$dir$section/$p->{slug}.html", $html);
        push @mapa, { loc => $url, lastmod => $p->{updated} || $p->{date}, image => $p->{image} };
    }

    # ---------- El índice de la sección ----------
    my $img0 = @arts ? $arts[0]{image} : 'hero-agency';
    my ($iw, $ih) = dims($img0);
    my $ld = [{
        '@context' => 'https://schema.org',
        '@graph'   => [
            {   '@type' => 'BreadcrumbList',
                'itemListElement' => [
                    { '@type' => 'ListItem', 'position' => 1, 'name' => $L->{home},    'item' => $home },
                    { '@type' => 'ListItem', 'position' => 2, 'name' => $L->{section}, 'item' => $sec_abs },
                ],
            },
            {   '@type'       => 'Blog',
                'name'        => $L->{sectionTitle},
                'description' => $L->{sectionDescription},
                'url'         => $sec_abs,
                'inLanguage'  => $lang,
                'publisher'   => $publisher,
                'blogPost'    => [ map { {
                    '@type' => 'BlogPosting', 'headline' => $_->{h1}, 'url' => "$sec_abs$_->{slug}.html",
                    'datePublished' => $_->{date}, 'image' => "$BASE/assets/img/$_->{image}.jpg",
                } } @arts ],
            },
        ],
    }];

    my $lista = join "\n", map { tarjeta($_, $L, $sec_url, 'h2') } @arts;
    my $html = cabeza(
        lang => $lang, locale => $d->{locale}, title => $L->{sectionTitle}, description => $L->{sectionDescription},
        canonical => $sec_abs, ogtype => 'website', image => $img0, imageAlt => (@arts ? $arts[0]{imageAlt} : ''),
        w => $iw, h => $ih, ld => $ld,
    ) . <<"HTML";
<body>
  $head<main id="main" class="post-main">
    <nav class="breadcrumb breadcrumb--top" aria-label="@{[ esc($L->{breadcrumb}) ]}">
      <ol>
        <li><a href="/$dir">@{[ esc($L->{home}) ]}</a></li>
        <li><span aria-current="page">@{[ esc($L->{section}) ]}</span></li>
      </ol>
    </nav>

    <section class="service-section posts-index">
      <h1 class="posts-title section-rule">@{[ esc($L->{section}) ]}</h1>
      <p class="section-deck">@{[ esc($L->{deck}) ]}</p>
      <ol class="post-list">
$lista
      </ol>
    </section>

@{[ cta($L, $dir) ]}  </main>

  $foot

  <script defer src="/main.js?v=$JSV"></script>
</body>
</html>
HTML
    escribe("$dir$section/index.html", $html);
    unshift @mapa, { loc => $sec_abs, lastmod => (@arts ? $arts[0]{updated} || $arts[0]{date} : undef), image => $img0 };
}

# ---------- El bloque de artículos del sitemap ----------
{
    open my $f, '<:encoding(UTF-8)', 'sitemap.xml' or die "falta sitemap.xml\n";
    local $/; my $s = <$f>; close $f;
    $s =~ s{\n  <!-- articulos:inicio -->.*?<!-- articulos:fin -->}{}s;

    my $bloque = "\n  <!-- articulos:inicio -->";
    for my $u (@mapa) {
        $bloque .= "\n  <url>\n    <loc>$u->{loc}</loc>";
        $bloque .= "\n    <lastmod>$u->{lastmod}</lastmod>" if $u->{lastmod};
        $bloque .= "\n    <image:image>\n      <image:loc>$BASE/assets/img/$u->{image}.jpg</image:loc>\n    </image:image>";
        $bloque .= "\n  </url>";
    }
    $bloque .= "\n  <!-- articulos:fin -->";
    $s =~ s{\n</urlset>}{$bloque\n</urlset>} or die "no encuentro el cierre del sitemap\n";

    open my $o, '>:encoding(UTF-8)', 'sitemap.xml' or die; print $o $s; close $o;
    printf "%-52s %d direcciones de artículos\n", 'sitemap.xml', scalar @mapa;
}
