import Foundation

// Decodificação tolerante: cada campo que faltar no JSON salvo (ex.: depois de uma
// atualização do app) usa o valor padrão, em vez de perder todas as configurações.
extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, default fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}
