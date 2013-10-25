{ stdenv, fetchurl, fetchgit, openjdk, glibcLocales, lib, zip, xz }:

with lib;
with builtins;

let
  scalacheckRepoUrl = "https://github.com/rickynils/scalacheck";

  docFooter = version: rev:
    let shortRev = builtins.substring 0 7 rev;
    in "ScalaCheck ${version} / ${shortRev} API documentation. © 2007-2013 Rickard Nilsson";

  docSourceUrl = version: rev:
    let tag = if hasSuffix "SNAPSHOT" version then rev else version;
    in "${scalacheckRepoUrl}/tree/${tag}/src/main/scala€{FILE_PATH}.scala";

  mkTestInterface = args: stdenv.mkDerivation rec {
    name = "test-interface-${args.version}";
    src = fetchurl {
      url = "http://search.maven.org/remotecontent?filepath=org/scala-sbt/test-interface/${args.version}/${name}.jar";
      inherit (args) sha256;
    };
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out/lib
      cp $src $out/lib/${name}.jar
      ln -s $out/lib/${name}.jar $out/lib/test-interface.jar
    '';
  };

  mkScala = args: stdenv.mkDerivation rec {
    name = "scala-${args.version}";
    src = fetchurl {
      url = "http://www.scala-lang.org/files/archive/${name}.tgz";
      inherit (args) sha256;
    };
    installPhase = ''
      mkdir -p $out
      rm -f bin/*.bat lib/scalacheck.jar
      mv bin lib $out/
    '';
  };

  test-interface = {
    "1.0" = mkTestInterface {
      version = "1.0";
      sha256 = "17klrl4ylpsy9d16fk6npb7lxfqr1w1m9slsxhph1wwmpcw0pxqm";
    };
  };

in rec {

  # Builds the given ScalaCheck with all Scala versions it supports
  mkScalaChecks = scVer: sc: mapAttrsToList (scalaVer: scala:
    mkScalaCheck scalaVer scala scVer sc
  ) sc.scalaVersions;

  # Builds the given ScalaCheck with the given Scala version
  mkScalaCheck = scalaVer: scala: scVer: sc: stdenv.mkDerivation rec {
    name = "scalacheck_${scalaVer}-${scVer}";

    src = fetchgit {
      url = scalacheckRepoUrl;
      inherit (sc) rev sha256;
    };

    buildInputs = [ openjdk (mkScala scala) ];

    doCheck = if sc ? runTests then sc.runTests else true;

    buildPhase = ''
      export LANG="en_US.UTF-8"
      export LOCALE_ARCHIVE=${glibcLocales}/lib/locale/locale-archive
      testinterface="${test-interface."1.0"}/lib/test-interface.jar"
      find src/main/scala -name '*.scala' > sources
      scalac \
        -classpath "$testinterface" \
        -optimise \
        -deprecation \
        -d ${name}.jar \
        @sources
    '';

    checkPhase = ''
      find src/test/scala -name '*.scala' > sources-test
      scalac \
        -classpath ${name}.jar \
        -optimise \
        -d ${name}-test.jar \
        @sources-test
      scala \
        -classpath ${name}.jar:${name}-test.jar \
        org.scalacheck.TestAll
    '';

    installPhase = ''
      mkdir -p "$out"
      mv "${name}.jar" "$out/"
    '';
  };

  mkScalaCheckDoc = scalaVer: scala: scVer: sc: stdenv.mkDerivation rec {
    name = "scalacheck-doc_${scalaVer}-${scVer}";
    fname = "scalacheck_${scalaVer}-${scVer}";

    src = fetchgit {
      url = scalacheckRepoUrl;
      inherit (sc) rev sha256;
    };

    buildInputs = [ xz zip openjdk (mkScala scala) ];

    buildPhase = ''
      export LANG="en_US.UTF-8"
      export LOCALE_ARCHIVE=${glibcLocales}/lib/locale/locale-archive
      testinterface="${test-interface."1.0"}/lib/test-interface.jar"
      find src/main/scala -name '*.scala' > sources
      mkdir "${fname}-api" && scaladoc \
        -doc-title ScalaCheck \
        -doc-version "${scVer}" \
        -doc-footer "${docFooter scVer sc.rev}" \
        -doc-source-url "${docSourceUrl scVer sc.rev}" \
        -classpath "$testinterface" \
        -sourcepath src/main/scala \
        -d "${fname}-api" \
        @sources
      mkdir "${fname}-sources"
      cp -rt "${fname}-sources" LICENSE RELEASE src/main/scala/*
    '';

    installPhase = ''
      mkdir -p "$out"
      jar cf "$out/${fname}-sources.jar" -C "${fname}-sources" .
      zip -r "$out/${fname}-sources.zip" "${fname}-sources"
      tar -czf "$out/${fname}-sources.tar.gz" "${fname}-sources"
      jar cf "$out/${fname}-javadoc.jar" -C "${fname}-api" .
      zip -r "$out/${fname}-javadoc.zip" "${fname}-api"
      tar -czf "$out/${fname}-javadoc.tar.gz" "${fname}-api"
      mv "${fname}-api" "$out/"
    '';
  };

  scalaVersions = {
    "2.9.1-1" = {
      version = "2.9.1-1";
      sha256 = "0b5lhfy33ng6q4rjz11j89k694h5x12ms9qdnv0ym3jav10r6qab";
    };
    "2.9.2" = {
      version = "2.9.2";
      sha256 = "0s1shpzw2hyz7bwxdqq19rcrzbpq4d7b0kvdvjvhy7h05x496b46";
    };
    "2.9.3" = {
      version = "2.9.3";
      sha256 = "1fg7qizxhgw6957plv99jh8p6z3rpi2w0cgxx1im154cywlv5aps";
    };
    "2.10.1" = {
      version = "2.10.1";
      sha256 = "0krzm6ln4ldy6wvk7mw93vnjsjf8pkylccnwz08hzj7wnvspgijk";
    };
    "2.10.2" = {
      version = "2.10.2";
      sha256 = "18v6jr42rif84q5cb82kynigqls2q5q3qnb61040m92496ygv4zn";
    };
    "2.10.3" = {
      version = "2.10.3";
      sha256 = "16ac935wydrxrvijv4ldnz4vl2xk8yb3yzb9bsi3nb9sic7fxl95";
    };
    "2.10" = scalaVersions."2.10.3";
    "2.11.0-M5" = {
      version = "2.11.0-M5";
      sha256 = "1zj89i0n3p4rrcj70hfi821qpc1qrzqjlivrb0iargvagrqq2ih2";
    };
  };

  scalacheckVersions = {
    "1.10.1" = {
      rev = "ecb39d126f919795738e3b0bb66dc088e31ccef3";
      sha256 = "1yjvh1r2fp46wdmsajmljryp03qw92albjh07vvgd15qw3v6vz3k";
      inherit scalaVersions;
    };
    "1.10.0" = {
      rev = "2338afc425a905fdc55b4fd67bd8bfc3358e3390";
      sha256 = "0a3kgdqpr421k624qhpan3krjdhii9fm4zna7fbbz3sk30gbcsnj";
      inherit scalaVersions;
    };
    "1.9" = {
      rev = "ddfd03e49b05fba702539a4aff03e60ea35a57e0";
      sha256 = "1dbxp9w7pjw1zf50x3hz6kwzm8xp3hvdbswnxsrcswagvqmc5kkm";
      runTests = false;
      inherit scalaVersions;
    };
    "1.8" = {
      rev = "f2175ed5ac20f37c1a7ec320b1c58de7a8e3c27f";
      sha256 = "0gkwnqw9wcv0p0dbc6w0i54zw9lb32qnl8qdsp3mn6ylkwj5zx0h";
      inherit scalaVersions;
    };
  };

}
