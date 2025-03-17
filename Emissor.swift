import SwiftUI
import AVFoundation
import CoreBluetooth
import CoreBluetoothMesh

class RadioTransmitter: NSObject, ObservableObject, CBPeripheralManagerDelegate {
    private var audioEngine = AVAudioEngine()
    private var peripheralManager: CBPeripheralManager?
    private var audioCharacteristic: CBMutableCharacteristic?
    private var meshNetwork: CBMeshNetwork?
    private var meshGroup: CBMeshGroup?
    @Published var isTransmitting = false

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        setupMeshNetwork()
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            let serviceUUID = CBUUID(string: "1234")
            let characteristicUUID = CBUUID(string: "5678")
            audioCharacteristic = CBMutableCharacteristic(type: characteristicUUID, properties: [.notify, .read], value: nil, permissions: [.readable])
            let service = CBMutableService(type: serviceUUID, primary: true)
            service.characteristics = [audioCharacteristic!]
            peripheralManager?.add(service)
        }
    }

    func setupMeshNetwork() {
        meshNetwork = CBMeshNetwork()
        meshGroup = CBMeshGroup(name: "RadioGroup")
        meshNetwork?.addGroup(meshGroup!)
    }

    func startTransmitting() {
        guard let characteristic = audioCharacteristic else { return }
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            if let data = buffer.toData() {
                self.meshNetwork?.publish(data, toGroup: self.meshGroup!)
            }
        }

        try? audioEngine.start()
        isTransmitting = true
    }

    func stopTransmitting() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isTransmitting = false
    }
}

extension AVAudioPCMBuffer {
    func toData() -> Data? {
        guard let floatChannelData = self.floatChannelData else { return nil }
        let frameLength = Int(self.frameLength)
        return Data(bytes: floatChannelData[0], count: frameLength * MemoryLayout<Float>.size)
    }
}

struct RadioTransmitterView: View {
    @ObservedObject var transmitter = RadioTransmitter()

    var body: some View {
        VStack {
            Text("ProCampus FM")
                .font(.custom("NoteWorthy", size: 34))
                .foregroundColor(.blue)
                .padding()

            HStack {
                Button(action: { transmitter.startTransmitting() }) {
                    Image(systemName: "mic.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }

                Button(action: { transmitter.stopTransmitting() }) {
                    Image(systemName: "stop.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(20)
    }
}
