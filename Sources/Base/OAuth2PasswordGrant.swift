//
//  OAuth2PasswordGrant.swift
//  OAuth2
//
//  Created by Tim Sneed on 6/5/15.
//  Copyright (c) 2015 Pascal Pfiffner. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation


/**
    A class to handle authorization for clients via password grant.
 */
public class OAuth2PasswordGrant: OAuth2 {
	
	public override class var grantType: String {
		return "password"
	}
	
	/// Username to use during authentication.
	public var username: String
	
	/// The user's password.
	public var password: String
	
	/**
	Adds support for the "password" & "username" setting.
	*/
	public override init(settings: OAuth2JSON) {
		username = settings["username"] as? String ?? ""
		password = settings["password"] as? String ?? ""
		super.init(settings: settings)
	}
	
	override func doAuthorize(params params: [String : String]? = nil) {
		self.obtainAccessToken(params: params) { params, error in
			if let error = error {
				self.didFail(error)
			}
			else {
				self.didAuthorize(params ?? OAuth2JSON())
			}
		}
	}
	
	/**
	Create a token request and execute it to receive an access token.
	
	- parameter callback: The callback to call after the request has returned
	*/
	func obtainAccessToken(params params: [String : String]? = nil, callback: ((params: OAuth2JSON?, error: ErrorType?) -> Void)) {
		do {
			let post = try tokenRequest(params: params)
			logIfVerbose("Requesting new access token from \(post.URL?.description)")
			
			performRequest(post) { data, status, error in
				do {
					guard let data = data else {
						throw error ?? OAuth2Error.NoDataInResponse
					}
					
					let dict = try self.parseAccessTokenResponse(data)
					if status < 400 {
						self.logIfVerbose("Did get access token [\(nil != self.clientConfig.accessToken)]")
						callback(params: dict, error: nil)
					}
					else {
						callback(params: dict, error: OAuth2Error.ResponseError("The username or password is incorrect"))
					}
				}
				catch let error {
					self.logIfVerbose("Error parsing response: \(error)")
					callback(params: nil, error: error)
				}
			}
		}
		catch let err {
			callback(params: nil, error: err)
		}
	}
	
	/**
	Creates a POST request with x-www-form-urlencoded body created from the supplied URL's query part.
	*/
	func tokenRequest(params params: [String : String]? = nil) throws -> NSMutableURLRequest {
		if username.isEmpty{
			throw OAuth2Error.NoUsername
		}
		if password.isEmpty{
			throw OAuth2Error.NoPassword
		}
		guard let clientId = clientConfig.clientId where !clientId.isEmpty else {
			throw OAuth2Error.NoClientId
		}
		
		let req = NSMutableURLRequest(URL: clientConfig.tokenURL ?? clientConfig.authorizeURL)
		req.HTTPMethod = "POST"
		req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
		req.setValue("application/json", forHTTPHeaderField: "Accept")
		
		// create body string
		var body = "grant_type=password&username=\(username.wwwFormURLEncodedString)&password=\(password.wwwFormURLEncodedString)"
		if let scope = clientConfig.scope {
			body += "&scope=\(scope.wwwFormURLEncodedString)"
		}
		if let params = params {
			body += "&" + self.dynamicType.queryStringFor(params)
		}
		if let secret = clientConfig.clientSecret where authConfig.secretInBody {
			logIfVerbose("Adding “client_id” and “client_secret” to request body")
			body += "&client_id=\(clientId.wwwFormURLEncodedString)&client_secret=\(secret.wwwFormURLEncodedString)"
		}
		
		// add Authorization header (if not in body)
		else if let secret = clientSecret {
			logIfVerbose("Adding “Authorization” header as “Basic client-key:client-secret”")
			let pw = "\(clientId.wwwFormURLEncodedString):\(secret.wwwFormURLEncodedString)"
			if let utf8 = pw.dataUsingEncoding(NSUTF8StringEncoding) {
				req.setValue("Basic \(utf8.base64EncodedStringWithOptions([]))", forHTTPHeaderField: "Authorization")
			}
			else {
				throw OAuth2Error.UTF8EncodeError
			}
		}
		req.HTTPBody = body.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
        
        if let data = req.HTTPBody  {
            if clientConfig.addHttpInfoToBodyForTesting {
                NSURLProtocol.setProperty(data, forKey:  "HTTPBody", inRequest: req)
            }
        }
        
		return req
	}
}

