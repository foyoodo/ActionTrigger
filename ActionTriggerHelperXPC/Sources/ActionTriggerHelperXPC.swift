import Cocoa

/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
public class ActionTriggerHelperXPC: NSObject, ActionTriggerHelperXPCProtocol {
    
    /// This implements the example protocol. Replace the body of this class with the implementation of this service's protocol.
    @objc public func uppercase(string: String, with reply: @escaping (String) -> Void) {
        let response = string.uppercased()
        reply(response)
    }

    @objc public func openFile(url: URL, withApp path: String, reply: @escaping ((Bool, String?)->Void)) {
        guard !path.isEmpty else {
            reply(false, nil)
            return
        }
        let conf = NSWorkspace.OpenConfiguration()
        conf.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: path), configuration: conf) { app, error in
            reply(app != nil, error?.localizedDescription)
        }
    }
}
