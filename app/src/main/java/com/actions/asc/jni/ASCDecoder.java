package com.actions.asc.jni;

/**
 * Created by inidhu on 2019/8/27.
 */

public class ASCDecoder {

    private static ASCDecoder mInstance;

    public synchronized static ASCDecoder getInstance() {
        if (mInstance == null) {
            mInstance = new ASCDecoder();
        }
        return mInstance;
    }

    static {
        System.loadLibrary("ASCDecoder");
    }

    public final static int ASC_I = 1;
    public final static int ASC_II = 2;
    public final static int ASC_III = 3;
    public final static int ASC_IV = 4;
    public final static int ASC_V = 5;
    public final static int ASC_VI = 6;
    public final static int ASC_VII = 7;

    public native short init(short codec);

    public native int readHead(short[] bytes);

    public native short[] decode(short[] bytes, short len, short codec);

    public native static void destroy();

}
