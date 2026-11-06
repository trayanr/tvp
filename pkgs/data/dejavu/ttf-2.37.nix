# Pre-generated licensed TTF data artifacts. No executable or font compilation.
{
  base,
  bash,
  coreutils,
  src,
  python,
}:
final: {
  pname = "dejavu-ttf-data";
  version = "2.37";
  inherit
    base
    bash
    coreutils
    src
    ;
  environment = {
    tools = [ python ];
    libraries = [ ];
  };
  plan = [
    {
      name = "font-data.install";
      tools = [ python ];
      run = ''
        ${python}/bin/python3 - "$out" ${final.src} <<'PY'
        import sys,tarfile,pathlib
        out=pathlib.Path(sys.argv[1]);fonts=out/'share/fonts/truetype';fonts.mkdir(parents=True)
        with tarfile.open(sys.argv[2]) as archive:
            for name in ['ttf/DejaVuSans.ttf','ttf/DejaVuSansMono.ttf','LICENSE']:
                member=archive.getmember('dejavu-fonts-ttf-2.37/'+name)
                target=fonts/pathlib.Path(name).name if name.startswith('ttf/') else out/'LICENSE'
                target.write_bytes(archive.extractfile(member).read());target.chmod(0o444)
        config=out/'etc/fonts/fonts.conf';config.parent.mkdir(parents=True)
        config.write_text('<!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig><dir>'+str(fonts)+'</dir><cachedir prefix="xdg">fontconfig</cachedir><alias><family>sans-serif</family><prefer><family>DejaVu Sans</family></prefer></alias><alias><family>serif</family><prefer><family>DejaVu Sans</family></prefer></alias><alias><family>monospace</family><prefer><family>DejaVu Sans Mono</family></prefer></alias></fontconfig>')
        PY
      '';
    }
  ];
  tvp.origin = {
    kind = "font-data-artifact";
    compiledFromSource = false;
    executable = false;
  };
}
