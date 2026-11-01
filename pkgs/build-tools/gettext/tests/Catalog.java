import java.util.Locale;
import java.util.ResourceBundle;
import gnu.gettext.GettextResource;
public class Catalog {
  public static void main(String[] args) {
    ResourceBundle g = ResourceBundle.getBundle("fixture", Locale.FRENCH);
    if (!GettextResource.gettext(g, "Hello").equals("Bonjour")) throw new AssertionError();
    if (!GettextResource.ngettext(g, "apple", "apples", 2).equals("pommes")) throw new AssertionError();
    System.out.println("ok");
  }
}
