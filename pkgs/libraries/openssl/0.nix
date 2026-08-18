{ defs }:
[
  {
    def = defs."0.9.6";
    status = {
      level = "broken";
      reason = "Configure has no x86_64 target: 0.9.6 predates AMD64 and offers only alpha, ia64, m68k, mips, ppc, s390, sparc and 32-bit linux-elf.";
      needs = "A period-appropriate architecture. Not fixable on x86_64-linux.";
    };
    releases = {
      "0.9.6" = "sha256-UhW2cMJnTfmmQlZepopn5tlV2O/MoaobTmpbT9J0Tug=";
      "0.9.6i" = "sha256-59i6mRAKUQetrEZd6MsVzTX9ScxtwbEnMWmAhUVlg1k=";
      "0.9.6j" = "sha256-PPct3ugGSOpFZ7Aw0C1bMdLhCVuDCD/tRO3boYWpkwM=";
      "0.9.6k" = "sha256-eLPwYwnagXHFwGuq/TAh3I/TMNYoxTXQhdWqcagROtE=";
      "0.9.6l" = "sha256-JyPnyLT66JkY89QKbRq53WGATe2Zh/aOAJr+i3B43Zc=";
      "0.9.6m" = "sha256-p3jAe13iSOGrizc0O8xgM/s62VXN1XmV6awKRM6UL9Y=";
    };
  }

  {
    def = defs."0.9.6";
    releases = {
      "0.9.7" = "sha256-CoBRPltBb69HBMbi2/3hG0gmlHm+QX8JIKooNg0lkQA=";
      "0.9.7a" = "sha256-1cVx3PPCLCrKa50tL5oILmDgfu45eqNFIxgXfR9QlaI=";
      "0.9.7b" = "sha256-LhniMMNuwXJzavdugx+aYYaAnDYzVXSPTlFAahEvCDE=";
      "0.9.7c" = "sha256-wLjHD9Z3xIGwL7nXsCDqVJZrf5tOmwtrK+fpAFLlZQY=";
      "0.9.7d" = "sha256-Bf39B+iBz+tYTneRnt3HTaw/laziOsvqAIwq+Ut2wUc=";
      "0.9.7e" = "sha256-JRIbXb0rgwkpUZMl4DMIbORYYc/y0AANko9IJhseC3w=";
      "0.9.7f" = "sha256-Nn2z7nXmMySyCQB0sSqBcCGLps7ziydWOQ0IlBwWJgg=";
      "0.9.7g" = "sha256-5+GihxQd0b5/S0/t1U7Cn6kEZV7XahOsh65po/x2sGI=";
      "0.9.7h" = "sha256-tjjDhTEtK9ao8BdsJgW9YTyXjlVdPS14AnDhYIfyDeE=";
      "0.9.7i" = "sha256-L92SNfwIxDU4ddCYF0GUfy+p+INfBNl8MEYcwUqYbdA=";
      "0.9.7j" = "sha256-ZabojDOXy2jRnbtXbs+fnY3EFCOqmsMCXNKeOYcnRGA=";
      "0.9.7k" = "sha256-m7znXVXAP61H98peZ5D6zKSyA7KMbDNCjRpHHvc+5iI=";
      "0.9.7l" = "sha256-ftGYWckuHBPp+O1cPeNcPUjkW/8bUv/EOEXMDIVvo9E=";
      "0.9.7m" = "sha256-yYuXA4h+LdpiF7kUBdDZSIP3xn4gX8TXqBu2kNLhBXI=";
    };
  }

  {
    def = defs."0.9.8";
    releases = {
      "0.9.8" = "sha256-wRVLimpFFodA7MnzjUbfrUDrJ65Rq9doM6GNTJpktR0=";
      "0.9.8a" = "sha256-MPj2H7Exb0+1FBDHQLSHm44mtBfI2HDkhhRLELgEHHM=";
      "0.9.8b" = "sha256-ae/tYnWUL5MS3mHPaarvErBsEvaxDzGWcs4CanVvZcA=";
      "0.9.8c" = "sha256-iW94MMGSFojyLG/k+z17dRic7915rMpfsMrStZkTkEg=";
      "0.9.8d" = "sha256-AiGUlEzCDa2RfIbJFtuKTgBQ3y3pG5tnQN3U+y2vF10=";
      "0.9.8e" = "sha256-QU6EKLlfvFFweWX9oxOQSX0FgpA1ZCa/4IS0lGSmA0A=";
      "0.9.8f" = "sha256-vlr9OG9des/wGayvRs2q2JqLQsyc7oXRrbJ3RifzK0I=";
      "0.9.8g" = "sha256-DiaIaEXelXFsnxubdcDgbp1AddK9yeEVBOql9+6QHPA=";
      "0.9.8h" = "sha256-Ik4co67tqKzHLlxIs0hDkEudWFqq201aFVJMJfbGoc4=";
      "0.9.8i" = "sha256-6Pxfz7cV/+klspgqqcooeDKpNJXX//A/F/ZEnwcycYw=";
      "0.9.8j" = "sha256-cTEkIELb1jH72DQ29CrqF3Xnwy9Yf6StpaAd9MOujos=";
    };
  }

  {
    def = defs."0.9.6";
    releases = {
      "0.9.8k" = "sha256-fnzU85dBmbcp5uOgrwi9Qnn94DcKESDBo7NRqwkMYQE=";
      "0.9.8l" = "sha256-7NBU6e7S6cFiC6FSV+b8TYgsmkrqZj0jt2niE43oyRo=";
      "0.9.8m" = "sha256-NgNxYCgc9Jd9lk5APSvAaA+8oKf/n2XjMTbXX64Sy1s=";
      "0.9.8n" = "sha256-sBq8KDdrhmUV31jxsATahFMWYpF4PU50d82omwAMHwE=";
      "0.9.8o" = "sha256-vvraGsOBmx0xffgZe16C7HaLOdJQ/L74Hisct/Fl1Eg=";
      "0.9.8p" = "sha256-smReKiryIfojC172qiuTiKh1gBt0y927Fr5Vf4D0UkI=";
      "0.9.8q" = "sha256-1SKz6KK0joO6HhQtcgXqygE1ihN7tY6NZFg1dOaX/9c=";
      "0.9.8r" = "sha256-QrI2j3hrBe076EaDjc4Sa06OPbqPsuDOgxAt8owQL60=";
      "0.9.8s" = "sha256-7cljm+ry1eI52OXJ0v4ZWeZyal1/irhDBhODX0Yj+bo=";
      "0.9.8t" = "sha256-a5s+9eqULXtcPOI+npKdjuzQkOgfGNh606ry65oiahQ=";
      "0.9.8u" = "sha256-BUjkuRcaYty76F5j2biXo13nGOD+GbP+VgAsj1o7pYc=";
      "0.9.8v" = "sha256-cBrE29J7kjeRmyFLU7wNCOXhRI8tD74cgEeSk9I3mmU=";
      "0.9.8w" = "sha256-U3QR/iz+JJqKW5iz+AmgftX5E7lKIWs8UQ/TUzGORZM=";
      "0.9.8x" = "sha256-fODH8sRRBwtEl+p8pvI+umzvGlbbLobkM/ZZJqe8dJc=";
      "0.9.8y" = "sha256-u+zxNJXmEpNuOphgwpwHAUE1ZLepZL93GjV16qhnzuM=";
      "0.9.8za" = "sha256-zcuY0PvAJsp5ixeRkzQxAnHTpZNVT/1qWWWbkiL9Tkg=";
      "0.9.8zb" = "sha256-lQ4imCN94WlxaN69QoYL9B6tYY4MA9yaOlbiMljkNb4=";
      "0.9.8zc" = "sha256-RhzGlPKecvWcIufqYb9EZxpfwviz/C7qyJcUt76RWIE=";
      "0.9.8zd" = "sha256-WSZtz7C+D75hge3q0ESsPtr4O8WJkfJk3PUysB1THuM=";
      "0.9.8ze" = "sha256-7j2mAoJul1tH5Neviie+gljBYIdhlImMWIgeq4FLVbg=";
      "0.9.8zf" = "sha256-1SRaKRKJhBkqzFsfwB43Qpt6AcU8rcsmReVGcYswDts=";
      "0.9.8zg" = "sha256-BlAAYGOZMORxBQR09Tf80o7JNK+S7igteLUkYPvo9YA=";
      "0.9.8zh" = "sha256-8dnz7RuFqC7PgNDi04nh/aP8qaTboL8Hrb8jHhpeL9Y=";
    };
  }
]
