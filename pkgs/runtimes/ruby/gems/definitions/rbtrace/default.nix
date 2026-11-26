{ ... }:
{
  inputs = { };
  configure = final: {
    tools = [
      final.base.tools.sed
      final.base.tools.gawk
      final.base.tools.grep
    ];
  };
}
