//
//  ProfileHeaderCell.swift
//  Yep
//
//  Created by NIX on 15/3/18.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import CoreLocation
import FXBlurView
import Proposer
import Navi

class ProfileHeaderCell: UICollectionViewCell {

    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var avatarBlurImageView: UIImageView!
    @IBOutlet weak var locationLabel: UILabel!
    
    var askedForPermission = false

    struct Listener {
        static let Avatar = "ProfileHeaderCell.Avatar"
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)

        YepUserDefaults.avatarURLString.removeListenerWithName(Listener.Avatar)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    var blurredAvatarImage: UIImage? {
        willSet {
            avatarBlurImageView.image = newValue
        }
    }

    var location: CLLocation? {
        didSet {
            if let location = location {

                // 优化，减少反向查询
                if let oldLocation = oldValue {
                    let distance = location.distanceFromLocation(oldLocation)
                    if distance < YepConfig.Location.distanceThreshold {
                        return
                    }
                }

                locationLabel.text = ""

                CLGeocoder().reverseGeocodeLocation(location, completionHandler: { (placemarks, error) in

                    dispatch_async(dispatch_get_main_queue()) { [weak self] in
                        if (error != nil) {
                            println("\(location) reverse geodcode fail: \(error?.localizedDescription)")
                        }

                        if let placemarks = placemarks {
                            if let firstPlacemark = placemarks.first {
                                self?.locationLabel.text = firstPlacemark.locality ?? (firstPlacemark.name ?? firstPlacemark.country)
                            }
                        }
                    }
                })
            }
        }
    }

    func configureWithDiscoveredUser(discoveredUser: DiscoveredUser) {
        updateAvatarWithAvatarURLString(discoveredUser.avatarURLString)

        location = CLLocation(latitude: discoveredUser.latitude, longitude: discoveredUser.longitude)
    }

    func configureWithUser(user: User) {

        updateAvatarWithAvatarURLString(user.avatarURLString)

        if user.friendState == UserFriendState.Me.rawValue {
            YepUserDefaults.avatarURLString.bindListener(Listener.Avatar) { [weak self] avatarURLString in
                dispatch_async(dispatch_get_main_queue()) {
                    if let avatarURLString = avatarURLString {
                        self?.blurredAvatarImage = nil // need reblur
                        self?.updateAvatarWithAvatarURLString(avatarURLString)
                    }
                }
            }

            if !askedForPermission {
                askedForPermission = true
                proposeToAccess(.Location(.WhenInUse), agreed: {
                    YepLocationService.turnOn()
                }, rejected: {
                        println("Yep can NOT get Location. :[\n")
                })
            }

            NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateAddress", name: "YepLocationUpdated", object: nil)
        }

        location = CLLocation(latitude: user.latitude, longitude: user.longitude)
    }


    func blurImage(image: UIImage, completion: UIImage -> Void) {

        if let blurredAvatarImage = blurredAvatarImage {
            completion(blurredAvatarImage)

        } else {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                let blurredImage = image.blurredImageWithRadius(20, iterations: 20, tintColor: UIColor.blackColor())
                completion(blurredImage)
            }
        }
    }

    func updateAvatarWithAvatarURLString(avatarURLString: String) {

        if avatarImageView.image == nil {
            avatarImageView.alpha = 0
            avatarBlurImageView.alpha = 0
        }

        let avatarStyle = AvatarStyle.Original
        let plainAvatar = PlainAvatar(avatarURLString: avatarURLString, avatarStyle: avatarStyle)

        AvatarPod.wakeAvatar(plainAvatar) { [weak self] finished, image in

            if finished {
                self?.blurImage(image) { blurredImage in
                    dispatch_async(dispatch_get_main_queue()) {
                        self?.blurredAvatarImage = blurredImage
                    }
                }
            }

            dispatch_async(dispatch_get_main_queue()) {
                self?.avatarImageView.image = image

                UIView.animateWithDuration(0.2, delay: 0.0, options: .CurveEaseOut, animations: { () -> Void in
                    self?.avatarImageView.alpha = 1
                }, completion: { (finished) -> Void in
                })
            }
        }
    }

    // MARK: Notifications
    
    func updateAddress() {
        locationLabel.text = YepLocationService.sharedManager.address
    }
}
