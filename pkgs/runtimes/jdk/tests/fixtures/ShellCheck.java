import java.nio.file.*;
import java.nio.charset.StandardCharsets;
public class ShellCheck {
    public static void main(String[] args) throws Exception {
        Path script=Path.of("script").toAbsolutePath();
        Files.writeString(script,"printf '%s' \"$BASH\"\n");
        if(!script.toFile().setExecutable(true)) throw new AssertionError("permissions");
        Process p=new ProcessBuilder(script.toString()).start();
        String output=new String(p.getInputStream().readAllBytes(),StandardCharsets.UTF_8);
        if(p.waitFor()!=0 || !output.equals(args[0])) throw new AssertionError("script fallback: "+output);
        ProcessBuilder changed=new ProcessBuilder(script.toString());
        changed.environment().put("TVP_CHILD", "changed");
        p=changed.start();
        output=new String(p.getInputStream().readAllBytes(),StandardCharsets.UTF_8);
        if(p.waitFor()!=0 || !output.equals(args[0])) throw new AssertionError("changed environment fallback: "+output);
        p=new ProcessBuilder("script").start();
        output=new String(p.getInputStream().readAllBytes(),StandardCharsets.UTF_8);
        if(p.waitFor()!=0 || !output.equals(args[0])) throw new AssertionError("PATH script fallback: "+output);
        System.out.println("shell-ok");
    }
}
