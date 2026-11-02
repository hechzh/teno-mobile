package com.teno.app;
import android.bluetooth.BluetoothDevice;
import java.io.IOException;
interface JwdTransport {
    void connect(BluetoothDevice device);
    void probe(BluetoothDevice device);
    void send(String command)throws IOException;
    void close();
}
