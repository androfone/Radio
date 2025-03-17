import SwiftUI
import AVFoundation
import CoreBluetooth
import CoreBluetoothMesh

class RadioReceiver: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var audioCharacteristic: CBCharacteristic?
    private var meshNetwork: CBMeshNetwork?
    private var meshGroup: CBMeshGroup?
    @Published var isReceiving = false

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        setupAudio()
        setupMeshNetwork()
    }

    func setupAudio() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        try? audioEngine.start()
    }

    func setupMeshNetwork() {
        meshNetwork = CBMeshNetwork()
        meshGroup = CBMeshGroup(name: "RadioGroup")
        meshNetwork?.addGroup(meshGroup!)
        meshNetwork?.subscribeToGroup(meshGroup!) { data in
            self.playAudio(data)
        }
    }

    func playAudio(_ data: Data) {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        _ = data.copyBytes(to: buffer.floatChannelData![0], count: data.count)

        playerNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        if !playerNode.isPlaying {
            playerNode.play()
            isReceiving = true
        }
    }
}

struct RadioReceiverView: View {
    @ObservedObject var receiver = RadioReceiver()

    var body: some View {
        VStack {
            if receiver.isReceiving {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(2.0)
                    .padding()
            } else {
                Text("Aguardando Transmissão...")
                    .font(.custom("NoteWorthy", size: 20))
                    .foregroundColor(.blue)
                    .padding()
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(20)
    }
}
