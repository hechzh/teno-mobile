package com.teno.app;

import android.annotation.SuppressLint;
import android.bluetooth.*;
import android.os.Handler;
import java.io.IOException;
import java.util.*;

/** All callbacks and GATT operations run on one handler. No raw commands are logged. */
@SuppressLint("MissingPermission")
final class JwdBle implements JwdTransport {
    interface Listener {void ready();void stage(String stage);void serviceChecked(boolean matches,String reason);void command(byte[] bytes);void audio(byte[] bytes);void closed(String reason);}
    private final android.content.Context context;private final Handler handler;private final Listener listener;
    private BluetoothGatt gatt;private BluetoothGattCharacteristic writer;
    private final ArrayList<BluetoothGattCharacteristic> notifications=new ArrayList<>();
    private final ArrayDeque<byte[]> writes=new ArrayDeque<>();
    private int notifyIndex,mtu=23;private boolean writing,ready,probeOnly;private long nextWrite;
    private final Runnable handshakeTimeout=()->fail("Connection timed out. Keep the recorder nearby and close other recorder apps before retrying.");
    private final Runnable writeTimeout=()->fail("Bluetooth command timed out. Reconnect the recorder.");
    JwdBle(android.content.Context c,Handler h,Listener l){context=c;handler=h;listener=l;}
    public void connect(BluetoothDevice device){connect(device,false);}
    public void probe(BluetoothDevice device){connect(device,true);}
    private void connect(BluetoothDevice device,boolean probe){
        close();probeOnly=probe;handler.postDelayed(handshakeTimeout,25000);
        try{gatt=device.connectGatt(context,false,callbacks,BluetoothDevice.TRANSPORT_LE);if(gatt==null)fail("Bluetooth connection could not start");}
        catch(Exception e){fail("Check Nearby devices permission and try again");}
    }
    private void dispatch(BluetoothGatt current,Runnable task){handler.post(()->{if(current!=gatt)return;try{task.run();}catch(Exception e){fail("Bluetooth operation failed: "+e.getClass().getSimpleName());}});}
    private final BluetoothGattCallback callbacks=new BluetoothGattCallback(){
        @Override public void onConnectionStateChange(BluetoothGatt g,int status,int state){dispatch(g,()->{
            if(status!=BluetoothGatt.GATT_SUCCESS||state==BluetoothProfile.STATE_DISCONNECTED){fail("Recorder disconnected (Bluetooth status "+status+"). Reconnect to continue.");return;}
            if(state==BluetoothProfile.STATE_CONNECTED){listener.stage("discovering_services");if(!g.discoverServices())fail("Device services could not be discovered");}
        });}
        @Override public void onServicesDiscovered(BluetoothGatt g,int status){dispatch(g,()->{
            if(status!=0){fail("Device service check failed ("+status+"). Device type has not been confirmed.");return;}
            BluetoothGattService service=g.getService(JwdProtocol.SERVICE);
            if(service==null){if(probeOnly){close();listener.serviceChecked(false,"No JWD service found. Choose another device.");}else fail("This device does not provide the JWD recording service");return;}
            writer=service.getCharacteristic(JwdProtocol.WRITE);notifications.clear();
            notifications.add(service.getCharacteristic(JwdProtocol.AUDIO));notifications.add(service.getCharacteristic(JwdProtocol.COMMAND));
            if(writer==null||notifications.contains(null)){if(probeOnly){close();listener.serviceChecked(false,"Recording channels are missing. This device is not supported.");}else fail("Required Bluetooth channels are missing");return;}
            boolean writable=(writer.getProperties()&(BluetoothGattCharacteristic.PROPERTY_WRITE|BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE))!=0;
            boolean notifiable=true;for(BluetoothGattCharacteristic c:notifications)notifiable&=(c.getProperties()&BluetoothGattCharacteristic.PROPERTY_NOTIFY)!=0&&c.getDescriptor(JwdProtocol.CCCD)!=null;
            if(!writable||!notifiable){if(probeOnly){close();listener.serviceChecked(false,"The recorder channels do not match the JWD protocol.");}else fail("The recorder channels do not match the JWD protocol.");return;}
            listener.stage("jwd_service_verified");
            // Discovery only: no CCCD writes, no bond request, and no APP&SK or other commands.
            if(probeOnly){close();listener.serviceChecked(true,"Recording service verified. You can now connect.");return;}
            listener.stage("requesting_mtu");if(!g.requestMtu(512))fail("Bluetooth data size could not be negotiated");
        });}
        @Override public void onMtuChanged(BluetoothGatt g,int size,int status){dispatch(g,()->{
            if(ready)return;
            if(status!=0||size<100){fail("Bluetooth packet size is too small for the recorder commands");return;}
            mtu=size;notifyIndex=0;subscribe();
        });}
        @Override public void onDescriptorWrite(BluetoothGatt g,BluetoothGattDescriptor d,int status){dispatch(g,()->{
            if(ready)return;
            if(status!=0){fail("Device notifications could not be enabled");return;}
            notifyIndex++;subscribe();
        });}
        @Override public void onCharacteristicWrite(BluetoothGatt g,BluetoothGattCharacteristic c,int status){dispatch(g,()->{
            if(!writing)return;handler.removeCallbacks(writeTimeout);writing=false;
            if(status!=0){fail("Device command failed ("+status+")");return;}
            // SDK demo warns that back-to-back application commands can be dropped by firmware.
            nextWrite=android.os.SystemClock.uptimeMillis()+850;handler.postDelayed(JwdBle.this::pump,850);
        });}
        @Override public void onCharacteristicChanged(BluetoothGatt g,BluetoothGattCharacteristic c){receive(g,c.getUuid(),c.getValue());}
        @Override public void onCharacteristicChanged(BluetoothGatt g,BluetoothGattCharacteristic c,byte[] value){receive(g,c.getUuid(),value);}
    };
    private void receive(BluetoothGatt g,UUID uuid,byte[] bytes){if(bytes==null)return;byte[] copy=bytes.clone();dispatch(g,()->{
        if(uuid.equals(JwdProtocol.AUDIO))listener.audio(copy);else if(uuid.equals(JwdProtocol.COMMAND))listener.command(copy);
    });}
    private void subscribe(){
        if(notifyIndex==notifications.size()){
            ready=true;handler.removeCallbacks(handshakeTimeout);gatt.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH);listener.stage("gatt_ready");listener.ready();return;
        }
        listener.stage(notifyIndex==0?"subscribing_audio":"subscribing_commands");
        BluetoothGattCharacteristic c=notifications.get(notifyIndex);BluetoothGattDescriptor d=c.getDescriptor(JwdProtocol.CCCD);
        if(d==null||!gatt.setCharacteristicNotification(c,true)){fail("The device notification channel is unavailable");return;}
        d.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);if(!gatt.writeDescriptor(d))fail("Notification setup failed");
    }
    public void send(String command)throws IOException{
        if(!ready||gatt==null)throw new IOException("Bluetooth is not ready");
        byte[] b=JwdProtocol.encode(command);if(b.length>mtu-3)throw new IOException("The command exceeds the Bluetooth packet limit");
        if(writes.size()>30)throw new IOException("Wait for the current device command to finish");writes.add(b);pump();
    }
    private void pump(){
        if(gatt==null||!ready||writing||writes.isEmpty())return;
        long wait=nextWrite-android.os.SystemClock.uptimeMillis();if(wait>0){handler.postDelayed(this::pump,wait);return;}
        writer.setWriteType((writer.getProperties()&BluetoothGattCharacteristic.PROPERTY_WRITE)!=0?BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT:BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE);
        writer.setValue(writes.remove());writing=true;handler.postDelayed(writeTimeout,6000);
        if(!gatt.writeCharacteristic(writer))fail("Bluetooth is busy. Reconnect and try again.");
    }
    public void close(){
        handler.removeCallbacks(handshakeTimeout);handler.removeCallbacks(writeTimeout);writes.clear();writing=false;ready=false;nextWrite=0;
        BluetoothGatt old=gatt;gatt=null;writer=null;
        if(old!=null){try{old.disconnect();}catch(Exception ignored){}try{old.close();}catch(Exception ignored){}}
    }
    private void fail(String reason){close();listener.closed(reason);}
}
