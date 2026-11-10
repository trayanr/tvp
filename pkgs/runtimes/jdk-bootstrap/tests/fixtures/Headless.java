import java.awt.GraphicsEnvironment;
import java.awt.image.BufferedImage;
public class Headless {
  public static void main(String[] args) {
    if (!GraphicsEnvironment.isHeadless()) throw new AssertionError();
    var image = new BufferedImage(16, 16, BufferedImage.TYPE_INT_RGB);
    var graphics = image.createGraphics();
    graphics.drawString("seed", 0, 12);
    graphics.dispose();
    System.out.println("headless");
  }
}
