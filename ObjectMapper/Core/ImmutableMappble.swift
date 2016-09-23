//
//  ImmutableMappble.swift
//  ObjectMapper
//
//  Created by Suyeol Jeon on 23/09/2016.
//  Copyright © 2016 hearst. All rights reserved.
//

public struct MapError: Error {
	public var key: String?
	public var currentValue: Any?
	public var reason: String?
}

extension MapError: CustomStringConvertible {
	public var description: String {
		let info: [(String, Any?)] = [
			("reason", reason),
			("key", key),
			("currentValue", currentValue),
		]
		let infoString = info.map { "\($0)=\($1 ?? "nil")" }.joined(separator: ", ")
		return "Got an error while mapping. (\(infoString))"
	}
}

public protocol ImmutableMappable: BaseMappable {
	init(map: Map) throws
}

public extension ImmutableMappable {
	/// Implement this method to support object -> JSON transform.
	public func mapping(map: Map) {}
}

extension Map {

	fileprivate func currentValue(for key: String) -> Any? {
		return self[key].currentValue
	}

}

public extension Map {

	// MARK: Basic

	/// Returns a value or throws an error.
	public func value<T>(_ key: String) throws -> T {
		let currentValue = self.currentValue(for: key)
		guard let value = currentValue as? T else {
			throw MapError(key: key, currentValue: currentValue, reason: "Cannot cast to '\(T.self)'")
		}
		return value
	}

	/// Returns a transformed value or throws an error.
	public func value<Transform: TransformType>(_ key: String, using transform: Transform) throws -> Transform.Object {
		let currentValue = self.currentValue(for: key)
		guard let value = transform.transformFromJSON(currentValue) else {
			throw MapError(key: key, currentValue: currentValue, reason: "Cannot transform to '\(Transform.Object.self)' using \(transform)")
		}
		return value
	}

	// MARK: BaseMappable

	/// Returns a `BaseMappable` object or throws an error.
	public func value<T: BaseMappable>(_ key: String) throws -> T {
		let currentValue = self.currentValue(for: key)
    return try Mapper<T>().mapOrFail(JSONObject: currentValue)
	}

	// MARK: [BaseMappable]

	/// Returns a `[BaseMappable]` or throws an error.
	public func value<T: BaseMappable>(_ key: String) throws -> [T] {
		let currentValue = self.currentValue(for: key)
		guard let jsonArray = currentValue as? [Any] else {
			throw MapError(key: key, currentValue: currentValue, reason: "Cannot cast to '[Any]'")
		}
		return try jsonArray.enumerated().map { i, json -> T in
      return try Mapper<T>().mapOrFail(JSONObject: json)
		}
	}

	/// Returns a `[BaseMapple]` using transform or throws an error.
	public func value<Transform: TransformType>(_ key: String, using transform: Transform) throws -> [Transform.Object] {
		let currentValue = self.currentValue(for: key)
		guard let jsonArray = currentValue as? [Any] else {
			throw MapError(key: key, currentValue: currentValue, reason: "Cannot cast to '[Any]' ")
		}
		return try jsonArray.enumerated().map { i, json -> Transform.Object in
			guard let object = transform.transformFromJSON(json) else {
				throw MapError(key: "\(key)[\(i)]", currentValue: json, reason: "Cannot transform to '\(Transform.Object.self)' using \(transform)")
			}
			return object
		}
	}

	// MARK: [String: BaseMappable]

	/// Returns a `[String: BaseMappable]` or throws an error.
	public func value<T: BaseMappable>(_ key: String) throws -> [String: T] {
		let currentValue = self.currentValue(for: key)
		guard let jsonDictionary = currentValue as? [String: Any] else {
			throw MapError(key: key, currentValue: currentValue, reason: "Cannot cast to '[String: Any]'")
		}
		var value: [String: T] = [:]
		for (key, json) in jsonDictionary {
      value[key] = try Mapper<T>().mapOrFail(JSONObject: json)
		}
		return value
	}

	/// Returns a `[String: BaseMappable]` using transform or throws an error.
	public func value<Transform: TransformType>(_ key: String, using transform: Transform) throws -> [String: Transform.Object] {
		let currentValue = self.currentValue(for: key)
		guard let jsonDictionary = currentValue as? [String: Any] else {
			throw MapError(key: key, currentValue: currentValue, reason: "Cannot cast to '[String: Any]'")
		}
		var value: [String: Transform.Object] = [:]
		for (key, json) in jsonDictionary {
			guard let object = transform.transformFromJSON(json) else {
				throw MapError(key: key, currentValue: json, reason: "Cannot transform to '\(Transform.Object.self)' using \(transform)")
			}
			value[key] = object
		}
		return value
	}

}

public extension Mapper where N: ImmutableMappable {

	public func map(JSON: [String: Any]) throws -> N {
		return try self.mapOrFail(JSON: JSON)
	}

	public func map(JSONString: String) throws -> N {
		return try mapOrFail(JSONString: JSONString)
	}

	public func map(JSONObject: Any?) throws -> N {
		return try mapOrFail(JSONObject: JSONObject)
	}

}

internal extension Mapper where N: BaseMappable {

	internal func mapOrFail(JSON: [String: Any]) throws -> N {
		let map = Map(mappingType: .fromJSON, JSON: JSON, context: context)
		if let klass = N.self as? ImmutableMappable.Type {
			return try klass.init(map: map) as! N
		}
		guard let value = self.map(JSON: JSON) else {
			throw MapError(key: nil, currentValue: JSON, reason: "Cannot map to '\(N.self)'")
		}
		return value
	}

	internal func mapOrFail(JSONString: String) throws -> N {
		guard let JSON = Mapper.parseJSONStringIntoDictionary(JSONString: JSONString) else {
			throw MapError(key: nil, currentValue: JSONString, reason: "Cannot parse into '[String: Any]'")
		}
		return try mapOrFail(JSON: JSON)
	}

	internal func mapOrFail(JSONObject: Any?) throws -> N {
		guard let JSON = JSONObject as? [String: Any] else {
			throw MapError(key: nil, currentValue: JSONObject, reason: "Cannot cast to '[String: Any]'")
		}
		return try mapOrFail(JSON: JSON)
	}

}
