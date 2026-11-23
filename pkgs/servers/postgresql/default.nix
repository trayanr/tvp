{ pkgs, tvp, ... }:
let
  pname = "postgresql";
  releaseDirectory = "https://ftp.postgresql.org/pub/source/";
  archivePool = "https://apt-archive.postgresql.org/pub/repos/apt/pool/main/p";
  archiveURL =
    version:
    let
      series =
        if builtins.compareVersions version "10" < 0 then
          pkgs.lib.versions.majorMinor version
        else
          pkgs.lib.versions.major version;
    in
    "${archivePool}/postgresql-${series}/postgresql-${series}_${version}.orig.tar.bz2";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-10.0.nix;
        deps = {
          icu = tvp.packages.icu_74;
          keyutils = tvp.packages.keyutils_1;
          krb5 = tvp.packages.krb5_1;
          libxml2 = tvp.packages.libxml2_2;
          # These source lines support the OpenSSL 1.1 interface.
          openssl = tvp.packages.openssl_1_1;
          readline = tvp.packages.readline_8;
          tzdata = tvp.packages.tzdata;
          zlib = tvp.packages.zlib_1;
        };
      };
      releases = {
        "10.0" = "sha256-cS9VkuJ7gcW0VN+WsljBTZS2sDg2gx4BXGXW3urlf9E=";
        "10.1" = "sha256-PMtOJf56fqYwjeoQPKwgKWPmt0Zpc2bXLsKQBEml5xM=";
        "10.2" = "sha256-/jIAm2LduX9/AUMHzp0O22ly9aaY5jy1MQiOFH0UW60=";
        "10.3" = "sha256-bqJoeA7jXojGXNsK95Va2Qt9DvNFc4Z/Ij8U5DRnkxo=";
        "10.4" = "sha256-G2CBIxC9V1bGLZOp+T3owo6mOw3yVPQozRzxpNkCAEg=";
        "10.5" = "sha256-bI5hbJGkUUK4XArrHynruko2EwnoZGng+0YXtqc8QBE=";
        "10.6" = "sha256-aKgnbwi9qPvv5WL6r4gxyyBmSnodP/27zFuD4IY3Yks=";
        "10.7" = "sha256-v+0QZTgMG7qSe/5R8jFoRxNz8m4zJMuthZJpzDJzPt4=";
        "10.8" = "sha256-sZjCqt8daDCBJ6D1tR2+eYlY/+YN2ZkTT2SVxImvzV0=";
        "10.9" = "sha256-lYsxf7AH6U87734qZkGHXbj3+dc9ufKDMk89bo9bD1Q=";
        "10.10" = "sha256-rU+bhXX5jtYJG/m7LLFvDlJ5Wl9mVGwfSZylxpsh8lM=";
        "10.11" = "sha256-DV0U/2sHVlX0QhA4+946XXtBjCaiSaGHpBdWANeuzAk=";
        "10.12" = "sha256-OI9/iIxPvL30JOwrzlJTUZW0JgELcgr3vqdn4j5ZSuc=";
        "10.13" = "sha256-TXAfRQzZL/sSPPbClullarvCq36mUHiU/x4kda4HVOE=";
        "10.14" = "sha256-OBzY9JHY932y9DJpdFQqUAlbX6dwnyTXxbdgviUYsjs=";
        "10.15" = "sha256-WVa84L7P+neIPEFZTJWiMRC5TxDNZqEVfjc8NXWSH34=";
        "10.16" = "sha256-o1xxixtmkOAcaWJtRn7bkzeE+NHWdB4h/mzOBzhGe7M=";
        "10.17" = "sha256-WvKAcWBsnNgiEsGbpYRlep0kDhxMLaKPwfOZiidUsmw=";
        "10.18" = "sha256-V0d8LtyCw/hqdHR3B7O6vB8wHziTFa4U6BngJcC6OAE=";
        "10.19" = "sha256-brgwtCi2DoSuh+IENrzmecTZ0CAr567A5BsMZ9kTQjk=";
        "10.20" = "sha256-h94W1ZvP5C+mBcMSxZvl4pToo+astlXdetR8u5MKZZ8=";
        "10.21" = "sha256-0yGYhW1Sqab11QZC74ZoesBYvW78pcntV754CElvRdE=";
        "10.22" = "sha256-lVl3VVxp3xpk9EuB1KGYfrdKu9GHBXn1rZ2UYTPdjk0=";
        "10.23" = "sha256-lKSyUoNyRY5WYsGNQGYpJmZnxDcZgWChjN/SxKTW7uk=";
        "11.0" = "sha256-v5u6A9DDkCwYivEuRUs1NDxKm/njd+wv5QEy77RO82s=";
        "11.1" = "sha256-kIFegSh0gx6aS/bhE2v3O8LFoEZO8ULi3+pAzaIG2wg=";
        "11.2" = "sha256-Jna5zgnCGXgDIHC2eUaW4KpaR249IdYK/ANtwKnAlAU=";
        "11.3" = "sha256-KoXggvwiWUSCHf0jmQ4y380ihMGQYIZLCtTKU30wUi0=";
        "11.4" = "sha256-AoAt3/0VkIBb7d0eRk3SikakGl8eHfBLq09GZjGVzIs=";
        "11.5" = "sha256-f98jBgv8cVFEy/JpbPBbD6KErT6yHww3hZHGvKma0YA=";
        "11.6" = "sha256-SZJPf/kpZf2yDIbgaW8tyfhVPhVjEk6te+7fiRDBMXA=";
        "11.7" = "sha256-MkrpOohG+7aiXVYtJxvEQf+oeUZUxbKDk4SDTeIgoxM=";
        "11.8" = "sha256-6vL0MpzMNJyJ6VB2G4Ha+MmbuJZqvKtWZczW7pXHeuI=";
        "11.9" = "sha256-NWGKpy4DcgkfkjxCOJxv69B1ExV7T7uUCDcXBq+7ZjU=";
        "11.10" = "sha256-E+bS+AZi/kY7x3GM3w3mqexn/HivzHo65mueoZu5eJk=";
        "11.11" = "sha256-QGB7f6FbfWP1B1pyd9r3s0Ekhqpds67f/bd2i5KYGGw=";
        "11.12" = "sha256-h/nYsWsrjvcVhvLsdr6shEgZ9kc0sH+jOYZ1XC9TywQ=";
        "11.13" = "sha256-oMNon/f1ZSiAAsvBOHedUSHXSDGl6DQa6nqobpm2vEg=";
        "11.14" = "sha256-llx/S+lvtk+VgYUsWMTwXDgS1K2CPA8+K9/nd8Fi+Zk=";
        "11.15" = "sha256-yPWOjr1PRWf0+boQMus+meAlHYfL4+VktIVZDjeoeeM=";
        "11.16" = "sha256-LdnhEfCllJ7nyswGXOoPshCSkpuuMQzgW/AbT/xRA6U=";
        "11.17" = "sha256-bphJY64HZeYVd5lRA6fmWU2w8L0BUorBI+DeSmpMtMQ=";
        "11.18" = "sha256-0k8g78UukYrPvMoh6c6ijg4mO4RqDECPz6w7PEoPdQQ=";
        "11.19" = "sha256-ExCeK3HxE5QFwnIB2jczphrOcu4cIo2cnwMg4GruFMI=";
        "11.20" = "sha256-PXyIgvZKfphTSgRCV9/uerrXelt9oSUI2F1yK5i1rM4=";
        "11.21" = "sha256-B7CDdHHV3XeyUWazRxjzuhCBa2rWHmkeb8VHzz/P+FA=";
        "11.22" = "sha256-LLfJfXoNcniFG7ycYfRntpwJTHK4F0C3URCOeJLr4fA=";
        "12.0" = "sha256-zaI5chX3WLeT90HIa+BUaCV7DmvLGmETiCq10N8IVcY=";
        "12.1" = "sha256-oJvzq7r2djmA0Pisu5Q7dimosgBz3hjYZ67Nt5iEg+0=";
        "12.2" = "sha256-rR3MTE/FAHhrdFY1qeHrqVAZXOILiRP1A0W7fVNptd4=";
        "12.3" = "sha256-lO1kpheQSBkGlchuxwfMJdAWBWzhD8nSKSZ9mo8dz0E=";
        "12.4" = "sha256-vuk/viwy9ZQZyxYrzAFFxY2pqGRO4VSjC5pc5H3mBsw=";
        "12.5" = "sha256-vQ0lNB2VeLVHPJUGMAAi3iY3CHlYH1/d0kOohs55/5U=";
        "12.6" = "sha256-333ZjVzK8faTx+HQ0ITp/tcBfuJIu6W+AWfEKtLXCgk=";
        "12.7" = "sha256-hJB0H0fIjtyLZiSvAJzhn9pNybMcRGnOJVHYQHXV2ZU=";
        "12.8" = "sha256-4mQB4JDDTMsV/7M6ER80CDODNTWnt8XNEc2Iq1fZxio=";
        "12.9" = "sha256-if2i3jPtBKmFSOQ/PuXxW4gr4XUF1jH+DdGlQKK1bc4=";
        "12.10" = "sha256-g90ZLmA0lRGSuahtwZzzcXqLghIOLxGgo2cjyCDSslc=";
        "12.11" = "sha256-ECYkil/Svur0PkxyNqyBflbVi2gaM1hWRl37x1s+gwI=";
        "12.12" = "sha256-NLPxxpQI4iBowMcbGCdpHxyJFTsK1XbBpE+JIKhYA5w=";
        "12.13" = "sha256-tsYjBGr0VI8RqEtAeTTWddEe0HDHk9FbBGg79fMi4C0=";
        "12.14" = "sha256-eFYQI304LIQtNW40cTjljAb/6uJA5swLUqxevMMNBD4=";
        "12.15" = "sha256-u1IG4oZMHEV5k4uW6mCW0VXyKr8tLMKqV1cePEyxKzY=";
        "12.16" = "sha256-xfH/96D5Ph7DdGQXsFlCkOzmF7SZXtlbjVJ68LoOOPM=";
        "12.17" = "sha256-k+jhsjmB1fA8bFdj93soGEwc5NtxlPpGbi7bZdnBxfY=";
        "12.18" = "sha256-T5kZcl2UHOmGjgf+HtHTqGdIWZtIM4ZUdYOSi3TDkYo=";
        "12.19" = "sha256-YX495Swi6CL09X0B1bIkBQPhmKnsyvWYqFEQm9GOb7s=";
        "12.20" = "sha256-LVQ68wCf7H/VrzX3pwyVCF0+72tQjlF6qUk+mbFenqk=";
        "12.21" = "sha256-bHEVUKwcx4KIZeWCPZ9Ffjva1vQyAXcWn5DkGb4MJ/I=";
        "12.22" = "sha256-jfPAR0eCWJ08bzdLUTOxvRTRaAhu28E8bnLmfdRSejs=";
        "13.0" = "sha256-gOdQvo1Da1QZdjagJjb4/TJjumd5v4ZbBIMklepZIpY=";
        "13.1" = "sha256-EjRcg7iaopgIVol39SANbaAPiKA1UX+SUpM1VDL/5h8=";
        "13.2" = "sha256-X9f80I24b1sq7Sj8+vmuCsqOlChWGsVHdkwqKw9Brfw=";
        "13.3" = "sha256-PNlFT6jHpiVbZ0O3Z3AJJerRuasNeg+dyxFRAQ+OtKE=";
        "13.4" = "sha256-6pPhA5AkXxzkYaVOtfmaSNjKvToIzk1lLsIWmjV7wM0=";
        "13.5" = "sha256-m4EGelXtuqvEGKrO9FfdhHdkKCdJlWCwBhWm6mwT9rM=";
        "13.6" = "sha256-uvx/o9nU2o/nG4TGO6i9/oCSk1wwwKqFwkssCFCPZ/w=";
        "13.7" = "sha256-G5Bb9PPYNhSjk7PFH9NFkQ/SYeT1Ekpo2aH906KkY5k=";
        "13.8" = "sha256-c4dv3TpRcIc0BFjcpM4VuNKk286zNMBEFCRVGubEze0=";
        "13.9" = "sha256-7xlmwKXkn77TNwrSgkkoy2sRZGF67q4WBtooP38zpBU=";
        "13.10" = "sha256-W7z1pW2FxE86iwWPtGhi/0nLyRg00H4pXQLm3jwhbfI=";
        "13.11" = "sha256-SZL/ZHIDVmtnDU5U3FMXSZomhWyTV20OqVG99r7lC/s=";
        "13.12" = "sha256-DaHtzuNRS3vHum268MAEmeisFZBmjoeJxQJTpiSfIYs=";
        "13.13" = "sha256-ivacJZkEeirSRlZ9aOxBMa7xFpVNjD5GnpeJCAs3pHQ=";
        "13.14" = "sha256-uN8HhVGJiWC9UA3F04oXfpkFN234H+fytmChQH+mpe0=";
        "13.15" = "sha256-Qu3UFURtM7jCQr520a0FdTGyJksuhpOTObcHXG5OySU=";
        "13.16" = "sha256-ycu7YSnwIyggSCgGa7N4XACoXIyo/TKcKopTwfXNiGU=";
        "13.17" = "sha256-AisKbnvDdKd37s4zcIiV17YMrgfUkrKGspaknXOV14s=";
        "13.18" = "sha256-zuqSq+4qjBlAjSeLaN5qeLa9PbtPotZT+nynRdZmqrE=";
        "13.19" = "sha256-SCzOCp+NJMJEfPx7KBflX4bVGv5ffxqFIUv5NkTndOo=";
        "13.20" = "sha256-gTS2hXJNFeYNk76iBvvg8UyClehPHMkdWjkoFj5Psog=";
        "13.21" = "sha256-3NoSlN9F8DOwZWz3qOSvu8Ykwl4bFErseVMPdNfvSrQ=";
        "13.22" = "sha256-022D3InmJVAs9vsdBSlkK6Ema9YUtOSkHO/R3dzwkIA=";
        "13.23" = "sha256-bsPIJyavkrfeyHP6HN+IHsqSpCGXh9+tBay2sQ4EH9Y=";
      };
    }
    {
      def = {
        builder = ./build.nix;
        deps = {
          icu = tvp.packages.icu_74;
          keyutils = tvp.packages.keyutils_1;
          krb5 = tvp.packages.krb5_1;
          libxml2 = tvp.packages.libxml2_2;
          # These source lines support the OpenSSL 1.1 interface.
          openssl = tvp.packages.openssl_1_1;
          readline = tvp.packages.readline_8;
          tzdata = tvp.packages.tzdata;
          zlib = tvp.packages.zlib_1;
        };
      };
      releases = {
        "14.0" = "sha256-7irXkSanN16RAsTbd8Ssrmrm/+PggkA7iIJtltknoSI=";
        "14.1" = "sha256-TTwQHqeuOJgvBr3HN1i1Nyf7ZALs2TggBvpezHwspB8=";
        "14.2" = "sha256-LPeLLkaJEvgQHWldtTQM8xPC6faKYS+3FCdSToyal3o=";
        "14.3" = "sha256-J5BXNov1mpGcBa2o+VxeBKu0PnS5oqacPUaiDgeprzg=";
        "14.4" = "sha256-wjtiN8UjHHkVEb3HkJhhfWhS6eO982Dv2LXRWho9j2o=";
        "14.5" = "sha256-1PcstfuFfJqfdeyM8JGhdxJygC8hePCy5lt7b/ZPSjA=";
        "14.6" = "sha256-UIhA/BgJ05q3InTV8Tfau5/X+0+TPaQWiu67IAae3yI=";
        "14.7" = "sha256-zvYPAJj6gQHBVG9CVORbcir1QxM3lFs3ryBwB2MNszE=";
        "14.8" = "sha256-OdOPADBzftA4Nd6+7+47N9M1RizkmV4kl7w41iHr5Fo=";
        "14.9" = "sha256-sf47qbGn86ljfdFlbf2tKIkBYHP9TTXxO1AUPLu2qO8=";
        "14.10" = "sha256-yZQxxI6dRwsNCrlG6yFBo80ZEwwvtNxLMoSnd07Mg5k=";
        "14.11" = "sha256-pnC9fc4i3K1Cl7JhE2s7HUoJpvVBcZViqhTKY78paKg=";
        "14.12" = "sha256-YRjQj53cwb2Dzyt8x007WDvc7C835iRaisADuPqoCSM=";
        "14.13" = "sha256-Wao8S0lasmqexp860KAijFHw/m+s82NN+tTRGX1hOlY=";
        "14.14" = "sha256-hHJ/vM29Hv4B2N5kvBszCV23c60kV8787cLYJY68CdY=";
        "14.15" = "sha256-AuiR4xS06e4ky9eAKNq3xz+cG6PjCDW8vvcf4iBAH8U=";
        "14.16" = "sha256-Zzwm8V67FDBq0OoFHYrPs5Fd00LelC9bUC5TVKCrdgw=";
        "14.17" = "sha256-bODM1kA79/Dy7d0zPi7pugLt+pd8ZmYO2bSxBX52MKE=";
        "14.18" = "sha256-g6sp1r/D3Fiy7TxmQRT9++tqBFDEuNf6aa7pHjyhT44=";
        "14.19" = "sha256-cn6eM0vBoxlA34CCWfaf5HpZ9tQhdLIq5i1n/noBrYA=";
        "14.20" = "sha256-dSfxDxZAdhvCgK2X0QXShtDPcuVNNteM9o5eX3UrZGs=";
        "14.21" = "sha256-WzDxk0fv/zK24J7Szf8LBOmu6RPsm7dBTeK3wXsX8fk=";
        "14.22" = "sha256-9Xk4rTAGcHdyAnf219sFqvwH0VRe/S7YLxmbqCinrTQ=";
        "14.23" = "sha256-zHIWgitUYzDinC+R4SPIc0pMQXlQghRbuWKqcS6MlKU=";
        "14.24" = "sha256-p/p+09VYFyNV9RQGCXp71Pa0c76A8xHvfNqWvzg9iJc=";
        "14.25" = "sha256-Ca+YDrOl0KitejS5UDGxmIu81DDIdwCmLWI0wO2Xrkw=";
      };
    }
    {
      def = {
        builder = ./build.nix;
        deps = {
          icu = tvp.packages.icu_74;
          keyutils = tvp.packages.keyutils_1;
          krb5 = tvp.packages.krb5_1;
          libxml2 = tvp.packages.libxml2_2;
          openssl = tvp.packages.openssl_3_0;
          readline = tvp.packages.readline_8;
          tzdata = tvp.packages.tzdata;
          zlib = tvp.packages.zlib_1;
          zstd = tvp.packages.zstd_1;
        };
      };
      releases = {
        "15.0" = "sha256-cux09KfBbmhPQ+pC4hVJf81MVdAopo+3LpnmH/QNpNY=";
        "15.1" = "sha256-ZP3yPXNK+tDf5Ad9rKlqxR3NaX5ori09TKbEXLFOIa4=";
        "15.2" = "sha256-maIXH8PWtbX1a3V6ejy4XVCaOOQnOAXe8jlB7SuEaMc=";
        "15.3" = "sha256-/8fUiR8A/79cP06rf7vO2EYLjA7mPFpRZxM7nmWZ2TI=";
        "15.4" = "sha256-uuxaS9xENzNmU7bLXZ7Ym+W9XAxYuU4L7O4KmZ5jyPk=";
        "15.5" = "sha256-j1OqldeOuOglNupGtoGHeTtCu6O09lqjQvVAsjybEKY=";
        "15.6" = "sha256-hFUUbtnGnJOlfelUrq0DAsr60DXCskIXXWqh4X68svs=";
        "15.7" = "sha256-pG/klIWrY4Xjnau7tlT10wSSBvds1pXiJCaHKVIJmPc=";
        "15.8" = "sha256-RANRX5pp7rPv68mPMLjGlhIr/fiV6Ss7I/W452nty2o=";
        "15.9" = "sha256-dPLUVlA18M9ynssFmUn6rxECy9k3WbNZgi+Y+CGYx4M=";
        "15.10" = "sha256-VavnONRB8OWGWLPsb4gJenE7XjtzE59iMNe1xMOJ5XM=";
        "15.11" = "sha256-U2fpfoHkkzAcxKqwSd+8m0kTgimFvGI3n6qyooHPvfA=";
        "15.12" = "sha256-O8hGKjjKCFcnDMiLlJo/Zlnw1cRMApxII1WDW2Gg9vc=";
        "15.13" = "sha256-T2LhM9IuoIoEAbCECSDiZphkTQGoDDQ0H7cy3QqQyl0=";
        "15.14" = "sha256-Bt110wXNOHDuYrOTLmYcYkVD6vmuK6N83sCk+O3QUdI=";
        "15.15" = "sha256-V1Oq64sJy/YQFveKppv1y98BtDJj8BDL8WjIKJYhOqo=";
        "15.16" = "sha256-aV7imne+H1AQ4Q82Z2lvKYcVh/eqMR6twfgJvqKHz0g=";
        "15.17" = "sha256-rhTyTBRyfgst7RxVUwMWZgmb0QVNs+9Ev6bivW1VSlY=";
        "15.18" = "sha256-Ed8N+X/j6kupp5H6rznO4dL+Vx54iFtbVdhRfSfDI7Q=";
        "15.19" = "sha256-4aZKh6RrgluIwILkUYFhpHqrU8RWlJZPi6HfKPeFn4k=";
        "15.20" = "sha256-MOZcu7dxo5tVPtLffmViLmVkeu1V28Gb0P6FP/CghEI=";
        "16.0" = "sha256-356CPrIjMEROHUjlLMZRNaZSpv2zzjJePwhUkzn1G5k=";
        "16.1" = "sha256-zjxNhdGbASH+DT+O8fpgH3GYnob4pm99w61UbdVWT+w=";
        "16.2" = "sha256-RG6IKU28LJCFq0twYaZG+mBLS+wDUh1epnHC5a2bKVI=";
        "16.3" = "sha256-Mxlj1dPcTK9CFqBJ+kC2bWvLjHMGFYWUEblRh2TmBYU=";
        "16.4" = "sha256-lxdm1kWqc+k7nvTjvkQgG09FtUdwlbBJElQD+fM4bW8=";
        "16.5" = "sha256-psu7cDf5jLivp9OXC3xIBAzwKxFeOSU6DAN6i7jnePA=";
        "16.6" = "sha256-Izac2szUUnCsXcww+p2iBdW+M/pQXh8XoEGNLK7KR3s=";
        "16.7" = "sha256-YuAvd+v8SjfxcAwgzDzNhf95e1YTdm6/lJp4mbshE/4=";
        "16.8" = "sha256-lGgIOlbODufSlGAbdNrT3Z/GnYev9h8Kn7Y8gT/379g=";
        "16.9" = "sha256-B8APuCTfCgwpXySfRGkbhuMmZ1OzgMlvYzwzEeEL0AU=";
        "16.10" = "sha256-3oSF9M6cMuPd/u8LfCYe7RzstUybzRcOQ3/0VMspK0I=";
        "16.11" = "sha256-besIwj0D132Pi9HBQEnu72Su+JaP2Ikd8t/AtC8Xjqw=";
        "16.12" = "sha256-slPulJMD713wDiQAJgDaT7N+XM+vp4cYxupqk2tNl/E=";
        "16.13" = "sha256-3C3bvSRcAmWmiUCOPS8vP5ui2pa9GTGCFLMTzdl5coc=";
        "16.14" = "sha256-9tB3FCc3kghYzpWMzbdcbuE3pjtbCFPHBpPUAax+NHE=";
        "16.15" = "sha256-wVdTQfp71A9SdOpGWzQ5D03GTN0HcK8ycAXKrrn2t+0=";
        "16.16" = "sha256-nVzYYzBDt1dA1dWXSca3Nl5q61PEcJixpegLsY+HiBo=";
        "17.0" = "sha256-fidhMcD91rYliNutmzuyS4w0mNUAkyjbpZrxboGRCd4=";
        "17.1" = "sha256-eEnbdO9qhVXQcj+H6BU5MBQi+pyOnyHM5h/cFOkZnc0=";
        "17.2" = "sha256-gu8nwK83UWldf2Ti2WNYMAX7tqDD32PQ5LQiEdcCEWQ=";
        "17.3" = "sha256-E8GLNb9nqXvWOZJfxYHbf9Kq5NNUjqw5/NuNp0rOK+o=";
        "17.4" = "sha256-xGBbc/6hGWNAZpn5Sblm5dFzp+4Myu+JON7AyoqZX+c=";
        "17.5" = "sha256-/LerOOI7Jk0ZAssl5q2vtFJabry9AVQ0ru+e2oD1KNg=";
        "17.6" = "sha256-4GMKNgCuonURcVVjJZ7CERzV9DU6SwQOC+gn+UzXqLA=";
        "17.7" = "sha256-7540MwLszTMRLxsvAke+STy1doMTretViwLeh5ei6bU=";
        "17.8" = "sha256-qI0ZXdk3MEUtDPoaEYlnINbRughLwr59f8VX+k5BWKA=";
        "17.9" = "sha256-O5piU4qNoVHoB6PdsRmOhgXyAyVE149AOuiD0n7PHuQ=";
        "17.10" = "sha256-B4oDUW3NvbcF/sr0Feo9E6lWxYnkbwn+1ooG+wBZjJA=";
        "17.11" = "sha256-3Sfys8Wec+0UqjMkkBJCv2mgMqY0eAXydOYmAyLUKXk=";
        "17.12" = "sha256-nPE2pwPY7i+DRlxDvk6ejnkwyCsL+6E75+JTe+dprFU=";
        "18.0" = "sha256-DVuQOx5f42G8p6qVB1GZM3c+s0JmsTV8TneA/e5tYHg=";
        "18.1" = "sha256-/4ZnXDNsRumKyZHrswbRtnYh7OHQZ4e+qt4xLCyRXVQ=";
        "18.2" = "sha256-UkW9G3lwDVW44Fdb4DJe9h57vvYn5qYW5M82rUaHvjY=";
        "18.3" = "sha256-2VZj+786gPganZjYlSZr3LdLonS8wE7212Ywpy3uAW8=";
        "18.4" = "sha256-gagexpX7DHkBQH3vqh0veXNhcVTPJ7p046erjmRDYJQ=";
        "18.6" = "sha256-VVYQwk1T5DFtpbfT/CXCedloVtXg4j7jCMMoxfqIHZ8=";
        "18.7" = "sha256-RB365CgMrj4EJeX4dvgFWfsHMcFA8ariKz5aVNBBG/0=";
        "19.0" = "sha256-qJ/XDvutagjH2+2NSHLjrzAXDZ5cqdx5BlI76VtOaS0=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = archiveURL;
      fetch =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = archiveURL version;
          inherit sha256;
          # Preserve the existing fixed-output store path despite the APT filename.
          name = "postgresql-${version}.tar.bz2";
        };
      discovery = {
        type = "directory-index";
        url = releaseDirectory;
        pattern = ''href="v[0-9]+[.][0-9]+([.][0-9]+)?/"'';
        normalise =
          link:
          let
            match = builtins.match ''href="v([0-9]+[.][0-9]+([.][0-9]+)?)/"'' link;
          in
          if match == null then null else builtins.head match;
      };
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.postgresql = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
