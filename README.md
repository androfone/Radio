# Radio

```swift
import SwiftUI
import AVFoundation
import Network

class RadioTransmitter: ObservableObject {
    var audioRecorder: AVAudioRecorder?
    var connection: NWConnection?
    @Published var isRecording = false
    @Published var selectedChannel: Double = 1
    var multicastGroup: NWEndpoint.Host
    var port: NWEndpoint.Port

    init(multicastGroup: String, port: UInt16) {
        self.multicastGroup = NWEndpoint.Host(multicastGroup)
        self.port = NWEndpoint.Port(rawValue: port) ?? 12345
        setupConnection()
    }

    func setupConnection() {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        connection = NWConnection(host: multicastGroup, port: port, using: parameters)
        connection?.start(queue: .main)
    }

    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .default)
        try? audioSession.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1
        ]
        
        let url = URL(fileURLWithPath: "/dev/null")
        try? audioRecorder = AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        isRecording = true
        
        DispatchQueue.global(qos: .background).async {
            while self.isRecording {
                self.sendAudioData()
            }
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
    }

    func sendAudioData() {
        guard let audioRecorder = audioRecorder, audioRecorder.isRecording else { return }
        audioRecorder.updateMeters()
        
        if let audioData = audioRecorder.recordedData {
            var channelData = Data()
            channelData.append(Data([UInt8(selectedChannel)]))
            channelData.append(audioData)
            connection?.send(content: channelData, completion: .contentProcessed({ _ in }))
        }
    }
}

struct RadioTransmitterView: View {
    @ObservedObject var radioTransmitter: RadioTransmitter

    var body: some View {
        VStack {
            Text("Rádio ProCampus")
                .font(.custom("NoteWorthy", size: 34))
                .foregroundColor(.blue)
                .padding()

            Text("Canal de Envio")
                .font(.custom("NoteWorthy", size: 20))
                .foregroundColor(.blue)

            Slider(value: $radioTransmitter.selectedChannel, in: 1...14, step: 1)
                .padding()

            Text("Canal: \(Int(radioTransmitter.selectedChannel))")
                .font(.custom("NoteWorthy", size: 20))
                .foregroundColor(.blue)

            HStack {
                Button(action: {
                    radioTransmitter.startRecording()
                }) {
                    Image(systemName: "mic.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }

                Button(action: {
                    radioTransmitter.stopRecording()
                }) {
                    Image(systemName: "stop.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
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

```

# Receptor

```swift
import SwiftUI
import AVFoundation
import Network

class RadioReceiver: ObservableObject {
    var audioPlayer: AVAudioPlayer?
    var listener: NWListener?
    @Published var selectedChannel: Int = 1
    var multicastGroup: NWEndpoint.Host
    var port: NWEndpoint.Port

    init(multicastGroup: String, port: UInt16) {
        self.multicastGroup = NWEndpoint.Host(multicastGroup)
        self.port = NWEndpoint.Port(rawValue: port) ?? 12345
        startListening()
    }

    func startListening() {
        do {
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            listener = try NWListener(using: parameters, on: port)
            listener?.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .main)
                self?.receiveAudio(from: connection)
            }
            listener?.start(queue: .main)
        } catch {
            print("Erro ao iniciar listener: \(error)")
        }
    }

    func receiveAudio(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, context, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.filterAndPlayAudio(data)
            }
            if isComplete {
                connection.cancel()
            } else {
                self?.receiveAudio(from: connection)
            }
        }
    }

    func filterAndPlayAudio(_ data: Data) {
        let channelIdentifier = data.first ?? 0
        if Int(channelIdentifier) == selectedChannel {
            let audioData = data.subdata(in: 1..<data.count)
            playAudio(audioData)
        }
    }

    func playAudio(_ data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            print("Erro ao reproduzir áudio: \(error)")
        }
    }
}

struct RadioReceiverView: View {
    @ObservedObject var radioReceiver: RadioReceiver

    var body: some View {
        VStack {
            Text("Rádio ProCampus")
                .font(.custom("NoteWorthy", size: 34))
                .foregroundColor(.blue)
                .padding()

            Spacer()

            if radioReceiver.audioPlayer?.isPlaying == true {
                Text("Reproduzindo Ao Vivo...")
                    .font(.custom("NoteWorthy", size: 20))
                    .foregroundColor(.blue)
                    .padding()
            } else {
                Text("Aguardando Transmissão")
                    .font(.custom("NoteWorthy", size: 20))
                    .foregroundColor(.blue)
                    .padding()
            }

            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(20)
    }
}

```
