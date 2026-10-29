import java.awt.image.BufferedImage;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.zip.*;
import javax.imageio.ImageIO;
import javax.xml.parsers.DocumentBuilderFactory;
public class RuntimeCheck {
    public static void main(String[] args) throws Exception {
        String digest=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest("abc".getBytes(StandardCharsets.UTF_8)));
        if(!digest.equals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")) throw new AssertionError("digest");
        byte[] xml="<root><answer>42</answer></root>".getBytes(StandardCharsets.UTF_8);
        ByteArrayOutputStream bytes=new ByteArrayOutputStream();
        try(GZIPOutputStream gz=new GZIPOutputStream(bytes)) { gz.write(xml); }
        var doc=DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(new GZIPInputStream(new ByteArrayInputStream(bytes.toByteArray())));
        if(!doc.getElementsByTagName("answer").item(0).getTextContent().equals("42")) throw new AssertionError("xml/gzip");
        BufferedImage image=new BufferedImage(2,2,BufferedImage.TYPE_INT_RGB);image.setRGB(1,1,0x123456);
        bytes.reset();if(!ImageIO.write(image,"png",bytes)) throw new AssertionError("png encoder");
        if((ImageIO.read(new ByteArrayInputStream(bytes.toByteArray())).getRGB(1,1)&0xffffff)!=0x123456) throw new AssertionError("png decoder");
        System.out.println("runtime-ok");
    }
}
