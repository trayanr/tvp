public class NativeCheck {
    static { System.loadLibrary("answer"); }
    public static native int answer();
    public static void main(String[] args) {
        if(answer()!=42) throw new AssertionError("JNI");
        System.out.println(answer());
    }
}
