{ defs }:
[
  {
    def = defs."3.0.0";
    releases = {
      "3.0.0" = "sha256-We7fy0bCUhTJvTftYHgpe03wHQEiZ/6enu4x9hvHBTY=";
      "3.0.1" = "sha256-wxGthTNTvOeW7a0BqGLFCopYf2Ln4hAO9GWrU+ybBtE=";
      "3.0.2" = "sha256-mOkczq1NR1auPJzeXgkZGo5YbZ9NUIOOfsCdZBHf22M=";
      "3.0.3" = "sha256-7gB4rc7x3l8APGLIDMllJ3IWCcbzu0K3eV3zH4tVjAs=";
    };
  }

  {
    def = defs."3.0.0";
    status = {
      level = "degraded";
      reason = "CVE-2022-2274: RSA corrupts memory on x86_64 CPUs with AVX512IFMA. The rsa test aborts, so it is not run here.";
      needs = "Nothing — upstream fixed it in 3.0.5. This release is preserved as it shipped.";
      knownTestFailures = [ "rsa" ];
    };
    releases = {
      "3.0.4" = "sha256-KDGEPppmigq0eOcCCtY9LWXlH3KXdHLcc+/O+6/AwA8=";
    };
  }

  {
    def = defs."3.0.0";
    releases = {
      "3.0.5" = "sha256-qn2Nm+9xrWUlxVuhHl9Dl4ic5Jwsk0nc6m0+TwsCSno=";
      "3.0.7" = "sha256-gwSdBComDmlvYkBqxcCL9wb9hDg/lFzyG9YentlcOW4=";
      "3.0.8" = "sha256-bBPSvzj98x6sPOKjRwc2c/XWMmM5jx9p0N9KQSU+Sz4=";
      "3.0.9" = "sha256-6xqwR4FHQ2D3fDGKuJ2MWgOrw45j1lpgPKu/GwCh3JA=";
      "3.0.10" = "sha256-F2HU9bE6ECi5tvPUuOF/6wztyTcPav5h1xk9LNzoMyM=";
      "3.0.11" = "sha256-s0JdO7SiIY0Gl+tB9/wM3t4BbtGcpJ0Wi3jo2UeIf1U=";
      "3.0.12" = "sha256-+Tyejt3l6RZhGd4xdV/Ie0qjSGNmL2fd/LoU0La2m2E=";
      "3.0.13" = "sha256-iFJXU/edO+wn0vp8ZqoLkrOqlJja/ZPXz6SzeAza4xM=";
      "3.0.14" = "sha256-7soDXU3U6E/CWEbZUtpil0hK+gZQpvhMaC453zpBI8o=";
      "3.0.15" = "sha256-I8Zm0O3yDxQkmz2PA2isrumrWFsJ4d6CEHxm4fPslTM=";
      "3.0.16" = "sha256-V+A8UP6rXTGxUq8rdk8QN5rs2O6S8WyYWYPOSpn374Y=";
      "3.0.17" = "sha256-39135OobV/86bb3msL3D8x21rJnn/dTq+eH7tuwtuM4=";
      "3.0.18" = "sha256-2Aw09c+QLczx8bXfXruG0DkuNwSeXXPfGzq65y5P/os=";
      "3.0.19" = "sha256-+lpBQ7iq4YvlPvLzyvKaLgdHQwuLx00y2IM1uUq2MHI=";
      "3.0.20" = "sha256-yAoB38cOzk3CEWiTLDdzkELUBNRszIGlmG3XUxTs2m8=";
      "3.0.21" = "sha256-YX4pr45CH0ZklISkk35IxoXkf0ZIgWfJgviLxOwdUi8=";
      "3.1.0" = "sha256-qqklrZgodFxMrZ2e/rJz3sqCDyzc8sOsfXwSErfEl7Q=";
      "3.1.1" = "sha256-s6phM0IzuFK2PdsEjfGBF3wsZZ651DdgCBGPnAjQdnQ=";
      "3.1.2" = "sha256-oM5puLl+pqNblodSNapFO5Zro8uory3iNlfYtnZ9ZTk=";
      "3.1.3" = "sha256-8DFqLr2J5/I1KXZEVFhon4AwIJN4jEZmkvsqGIsurPY=";
      "3.1.4" = "sha256-hAr1Nmq5tSK95SWCa+PvD7Cvgcap69hMqmAP6hcx7uM=";
      "3.1.5" = "sha256-auAVRn2r8EabE5rakzGTJ74kuYJR/67O2gIhhI3AkmI=";
      "3.1.6" = "sha256-XSvkA2tHjvPLCoVMqbNTByw6DibYpW+PCrn7btMtONc=";
      "3.1.7" = "sha256-BTox+oDPSuvhBoyYfS7x5EzkGIgUJ8RGR1GugAwx0Gw=";
      "3.1.8" = "sha256-0xnaauzeOqb0JrRLv5l0BtlSdcXFmrb271PKqgefRW8=";
      "3.2.0" = "sha256-FMgm8Hx+QzcG+1xp+p4l2rlWhIRLTJYqLPG/GD60aQ4=";
      "3.2.1" = "sha256-g8cyn+UshQZ3115dCwyiRTCbl+jsvP3B39xKufrDWzk=";
      "3.2.2" = "sha256-GXFJwY2enyksQ/BACsq6EuX1LKz+BQ89GZJ36nOOwuc=";
      "3.2.3" = "sha256-UrXxxrgCK8WGjDCMVPt3cF5wLWxvRZT5mg3yFqz0Yjk=";
      "3.2.4" = "sha256-sjrX/Z9z5DrRdn5jYEDoi6fJ5Xdb+lYYQ2oN0sF8NxY=";
      "3.2.5" = "sha256-s2NH0CSg9b0J/vzWr3pYuzCUYIDrjOj3vnhWIZDQmHk=";
      "3.2.6" = "sha256-iWgandqp7XzyXqjvYTONuAUgC65H0AUQSQYjVHOAwUg=";
      "3.3.0" = "sha256-U+ZrBDMipgar8Ah+dpmg4DOjf6E/65dC3zXDozsY+wI=";
      "3.3.1" = "sha256-d3zVlihMiDN1oqehG/XSeG/FQTJV76sgxQ1v/m0CC34=";
      "3.3.2" = "sha256-LopAsBl5r+i+C7+z3l3BxnCf7bRtbInBDaEUq1/D0oE=";
      "3.3.3" = "sha256-cSWQ/SCqpg7HXXeP5bgQ1rgpyn+x5TBXeRehMfkQVTk=";
      "3.3.4" = "sha256-jRpfwyPT/TUdwFRYRX/Uj3hlLSpJjh1w/+oHtNDrP6g=";
      "3.3.5" = "sha256-nWLAClppA3QMhwPw4AYlf0KdVl07kawam9SkxwAALgE=";
      "3.3.6" = "sha256-ItsE88j5qAjJeV3PfScT/0DBLEEOotH2Q1xsnIVYlYs=";
      "3.3.7" = "sha256-SQC+VOgcTf4AuxoQ2tM/2EFIM1c8QNDp4ydNTtMuU6I=";
      "3.4.0" = "sha256-4V3agv4v6BOdwqwho21MoB1TE8dfmfRsTooncJtylL8=";
      "3.4.1" = "sha256-ACotazC1i/S+pGxDvdljZar42qbEKHgqpP7uBtoZffM=";
      "3.4.2" = "sha256-F7AkWfwovkFUcMzKrnQ080lsrBMGuGtSyDiGWA6Cg0w=";
      "3.4.3" = "sha256-+nJ+0TmaZOdUAwoDNDUAOZGu42vamlsICZXLKsXPfzc=";
      "3.4.4" = "sha256-e99VrCDyd56Z5eyjBvgk+tKzfe5aBsw17VqLhaYGABA=";
      "3.4.5" = "sha256-xaaSkjTblB7KcJt523HT+8mBnukTJM3qv4mENsINzdw=";
      "3.4.6" = "sha256-pXuKHwm1AskENSyKU4aYdnXy1sUrwVX5ovQW+uocBHM=";
      "3.5.0" = "sha256-NE0KefGpsIApsHROLMQBpD+ckKzRBE0JpTC0iFqOn8A=";
      "3.5.1" = "sha256-UpBDsVz/pfNgd6TQr4Pz3jmYBxgdYHRB1zQZbYibZB8=";
      "3.5.2" = "sha256-xTpH5eRByTDDkoz3v2+wDl0Sm2MOCqhzsIJYZW5zRew=";
      "3.5.3" = "sha256-yUidKrz5Q83IMppXCSMxxZikApOAVNw6IiGK6oqOw78=";
      "3.5.4" = "sha256-lnMR+ElVMWlpvbHY1LmDcY70IzhjnGIexMNP3e81Xpk=";
      "3.5.5" = "sha256-soyRUyqLZaH5g7TCi3SIF05KAQCOKc6Oab14nyi8Kok=";
      "3.5.6" = "sha256-3q58gMupnEtPlA7K2zwzOLE8t3QYQJI45X1/MfKjtzY=";
      "3.5.7" = "sha256-qMDSilKcpID582z1eS4s0hmEVSo8jkqhGiSqMa6smOg=";
      "3.6.0" = "sha256-tqX0S362nj+jXb8VUkQFtEg3pIHUPYHa3d4/8h/LuOk=";
      "3.6.1" = "sha256-sb/tzVson/Iq7ofJ1gD1FXZ+v0X3cWjLbWTyMfUYqC4=";
      "3.6.2" = "sha256-qvUaH+BkOE+BHa6utOxNznNA7IvYkwJ+7mdq8x6DoE8=";
      "3.6.3" = "sha256-JDqGZJz28j7rai/yRW4J5dd92QGKVNPZawxr3Wumx/E=";
    };
  }
]
