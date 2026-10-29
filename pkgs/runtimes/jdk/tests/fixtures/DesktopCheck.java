import java.awt.*;
import java.awt.image.BufferedImage;
import java.awt.print.*;
import java.io.*;
import java.nio.file.*;
import javax.print.*;

public class DesktopCheck {
    public static void main(String[] args) throws Exception {
        Font font = Font.createFont(Font.TRUETYPE_FONT, new File(args[0])).deriveFont(32f);
        if (!font.canDisplay('A')) throw new AssertionError("font glyph");
        BufferedImage image = new BufferedImage(96, 64, BufferedImage.TYPE_INT_RGB);
        Graphics2D graphics = image.createGraphics();
        graphics.setColor(Color.WHITE);
        graphics.fillRect(0, 0, 96, 64);
        graphics.setColor(Color.BLACK);
        graphics.setFont(font);
        graphics.drawString("A", 16, 48);
        graphics.dispose();
        int ink = 0;
        for (int y = 0; y < 64; y++) for (int x = 0; x < 96; x++) {
            if ((image.getRGB(x, y) & 0xffffff) != 0xffffff) ink++;
        }
        if (ink == 0) throw new AssertionError("font rendering");
        var factories = StreamPrintServiceFactory.lookupStreamPrintServiceFactories(
            DocFlavor.SERVICE_FORMATTED.PRINTABLE, "application/postscript");
        if (factories.length == 0) throw new AssertionError("PostScript service");
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        var service = factories[0].getPrintService(output);
        PrinterJob job = PrinterJob.getPrinterJob();
        job.setPrintService(service);
        job.setPrintable((g, page, number) -> {
            if (number != 0) return Printable.NO_SUCH_PAGE;
            g.setFont(font);
            g.drawString("A", 80, 100);
            return Printable.PAGE_EXISTS;
        });
        job.print();
        service.dispose();
        if (output.size() < 1024 || !output.toString("ISO-8859-1").startsWith("%!PS"))
            throw new AssertionError("PostScript output");
        // Initialize the JNI bridge without connecting to a printing daemon.
        Class.forName("sun.print.CUPSPrinter");
        System.out.println("desktop-headless-ok");
    }
}
