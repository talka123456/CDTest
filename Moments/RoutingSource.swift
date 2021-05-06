//
//  RoutingSource.swift
//  Moments
//
//  Created by Jake Lin on 4/2/21.
//

import Foundation
import UIKit

protocol RoutingSource: class { }

typealias RoutingSourceProvider = () -> RoutingSource?

extension UIViewController: RoutingSource { }
