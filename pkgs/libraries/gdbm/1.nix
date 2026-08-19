{ defs }:
[
  {
    def = defs."1.7.3";
    status = {
      level = "degraded";
      capability = "shared";
      reason = "Static library only. This release predates libtool in gdbm; `all` builds libgdbm.a and there is no shared-library rule to install.";
      needs = "The libtool build upstream first shipped at 1.8.0.";
    };
    releases = {
      "1.7.3" = "sha256-gcBuiEc9aw/SI7nCf+c7u8yB3NT5OLmtzfX/K5m73no=";
    };
  }

  {
    def = defs."1.8.0";
    releases = {
      "1.8.0" = "sha256-S8jhb/4n+nF7Y1LPr0eiZbIG36nhhhZlZKcotzOP9xk=";
      "1.8.1" = {
        sha256 = "sha256-VqMk/7VJSuFqKwoEqAa4IWk3E4ZcPbHjIAmzbdB2WBE=";
        status = {
          level = "degraded";
          knownTestFailures = [
            "store"
            "ndbm"
          ];
          reason = "gdbm_open returns a handle in reader mode whatever mode is asked for, so every write fails with GDBM_READER_CANT_STORE. Measured against GDBM_NEWDB and GDBM_WRCREAT; 1.8.0 and 1.8.2 both write.";
          needs = "Nothing TVP can supply. Upstream shipped 1.8.2 the following day.";
        };
      };
      "1.8.2" = "sha256-DVr8LcDBTLo5Y2PMFeHKeFOoXV2Z6rW2tKnq95llImk=";
      "1.8.3" = "sha256-zDQDOKLii0AFirnrU1SiHVP4ihWC6iG6C7GFw3ooHck=";
    };
  }

  {
    def = defs."1.9";
    releases = {
      "1.9" = "sha256-+FMk1943d9sWdYH9XTST0tqj6F4ZWorpr8BbNFUbblc=";
      "1.9.1" = "sha256-YCWFJjd3KwaZ8ilLXxT9SghLyjyBYdKdZNHzDW0amu0=";
    };
  }

  {
    def = defs."1.10";
    releases = {
      "1.10" = "sha256-I/gTTFuUu/sG11amt48HT7puYCjPL+ATQdQLJtt3NEE=";
      "1.11" = "sha256-jZEvRPBdCxWkpdlqdvhS6QXQUbuIAi/N/Zi0O+CT48M=";
      "1.12" = "sha256-2XshZu6Gf9bKXAIu/ugHAtbzDdZq8OA+0JIoXDr5vOo=";
      "1.13" = "sha256-nSUsvX15P3sSvM6t3amNJXwU9NGJDYUcOGw3IHAAolM=";
      "1.14" = "sha256-raFDekFlpwez6fN7W3Tbvnwvi95jO4wsfbyPhPObqgk=";
      "1.14.1" = "sha256-zc7/AP/gFElb7TrtcceRCqiL8pN595WrwPRtTuX4vF8=";
      "1.15" = "sha256-+f3jIH9n7YpaXd2K1ees97J8LPDyDfvd6Hbc1uPS3A4=";
      "1.16" = "sha256-yKGLxiWdoMPu/vsBj4qimP3cb4bG/A8N7HMnCJarUS8=";
      "1.17" = "sha256-fNjMLjWxqu3mCE6lfMlEd1L0mNquqFQQCkutVnYUl30=";
      "1.18" = "sha256-uIIstHaeLXWcgowG8ZZhSTbIjBQcMTKxglL+JcK2Nc4=";
      "1.18.1" = "sha256-huYTUn5dulROcyCPQreLfAItT6Wm1UmL8YyNb3Rbkdw=";
    };
  }

  {
    def = defs."1.19";
    releases = {
      "1.22" = "sha256-82bII6ZySvMTtrvpdbKAn5oVfl9qQ2EqcpSRONFh12I=";
      "1.21" = "sha256-sLfb3v15jefdzN2O32aTowSU93iXd4OAQpke8QcznMI=";
      "1.20" = "sha256-OurAVkizSCoQotqYa586OAoprWUL6AuYF6Q1+4EUopI=";
      "1.19" = "sha256-N+0SIUEiuXLhig2UmVA55XdIGRk573QRWx1B2IETZLw=";
      "1.23" = "sha256-dLEIHSH/8TrkvXwW5dblBKTCb3zeHcoNljpIQXS7ys0=";
      "1.24" = "sha256-aV6YJ/33Y1E/EzkQvH5s/bkYeUOk/slD5XRJcj0rjb8=";
      "1.25" = "sha256-0C2zxZJu2Hf4gXuBzR+S9T73TKjG21Q/u6AnGzTzk+w=";
      "1.26" = "sha256-aiRQShTeSnRBA9y5Nr6Xbfb76IzP8mBl5UwcR5RvSl4=";
    };
  }
]
