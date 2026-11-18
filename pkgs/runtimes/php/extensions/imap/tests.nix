{ tvp }:
{
  package,
  lib,
  context,
}:
let
  runtime = import ../../with-extensions.nix {
    inherit lib tvp;
    php = package.php;
    extensions = [ package ];
  };
in
context.mkSuite {
  inherit package;
  tools = [ runtime ];
  tests = {
    load = {
      script = ''${runtime}/bin/php -r 'echo phpversion("imap");' '';
      expected = package.version;
    };
    roundtrip = {
      script = ''
        cat > fixture.mbox <<'MAIL'
        From sender@example.test Sat Jan  1 00:00:00 2022
        From: Sender <sender@example.test>
        To: Receiver <receiver@example.test>
        Subject: TVP fixture
        Date: Sat, 1 Jan 2022 00:00:00 +0000

        local mailbox payload

        MAIL
        ${runtime}/bin/php -r '
          $mailbox = imap_open(__DIR__ . "/fixture.mbox", "", "", OP_READONLY);
          if (!$mailbox || imap_num_msg($mailbox) !== 1) {
            throw new RuntimeException("Expected one message in the fixture mailbox");
          }
          echo imap_headerinfo($mailbox, 1)->subject, ": ", trim(imap_body($mailbox, 1));
          imap_close($mailbox);
        '
      '';
      expected = "TVP fixture: local mailbox payload";
    };
  };
}
