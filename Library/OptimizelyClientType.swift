import Foundation
import KsApi
import Prelude

public protocol OptimizelyClientType: AnyObject {
  func activate(experimentKey: String, userId: String, attributes: [String: Any?]?) throws -> String
  func getVariationKey(experimentKey: String, userId: String, attributes: [String: Any?]?) throws -> String
  func track(eventKey: String, userId: String, attributes: [String: Any?]?, eventTags: [String: Any]?) throws
}

extension OptimizelyClientType {
  public func variant(
    for experiment: OptimizelyExperiment.Key,
    userAttributes: [String: Any]? = optimizelyUserAttributes()
  ) -> OptimizelyExperiment.Variant {
    let variationString: String?

    let userId = deviceIdentifier(uuid: UUID())
    let isAdmin = AppEnvironment.current.currentUser?.isAdmin ?? false

    if isAdmin {
      variationString = try? self.getVariationKey(
        experimentKey: experiment.rawValue, userId: userId, attributes: userAttributes
      )
    } else {
      variationString = try? self.activate(
        experimentKey: experiment.rawValue, userId: userId, attributes: userAttributes
      )
    }

    guard
      let variation = variationString,
      let variant = OptimizelyExperiment.Variant(rawValue: variation)
    else {
      return .control
    }

    return variant
  }
}

// MARK: - Tracking Properties

public func optimizelyTrackingAttributesAndEventTags(
  with project: Project? = nil,
  refTag: RefTag? = nil
) -> ([String: Any], [String: Any]) {
  let properties = optimizelyUserAttributes(with: project, refTag: refTag)

  let eventTags: [String: Any] = ([
    "project_subcategory": project?.category.name,
    "project_category": project?.category.parentName,
    "project_country": project?.location.country.lowercased(),
    "project_user_has_watched": project?.personalization.isStarred
  ] as [String: Any?]).compact()

  return (properties, eventTags)
}

public func optimizelyUserAttributes(
  with project: Project? = nil,
  refTag: RefTag? = nil
) -> [String: Any] {
  let user = AppEnvironment.current.currentUser

  let properties: [String: Any] = [
    "user_distinct_id": debugAdminDeviceIdentifier(),
    "user_backed_projects_count": user?.stats.backedProjectsCount,
    "user_launched_projects_count": user?.stats.createdProjectsCount,
    "user_country": (user?.location?.country ?? AppEnvironment.current.config?.countryCode)?.lowercased(),
    "user_facebook_account": user?.facebookConnected,
    "user_display_language": AppEnvironment.current.language.rawValue,
    "session_os_version": AppEnvironment.current.device.systemVersion,
    "session_user_is_logged_in": user != nil,
    "session_app_release_version": AppEnvironment.current.mainBundle.shortVersionString,
    "session_apple_pay_device": AppEnvironment.current.applePayCapabilities.applePayDevice(),
    "session_device_format": AppEnvironment.current.device.deviceFormat
  ]
  .compact()
  .withAllValuesFrom(sessionRefTagProperties(with: project, refTag: refTag))

  return properties
}

private func sessionRefTagProperties(with project: Project?, refTag: RefTag?) -> [String: Any] {
  return ([
    "session_referrer_credit": project.flatMap(cookieRefTagFor(project:)).coalesceWith(refTag)?.stringTag,
    "session_ref_tag": refTag?.stringTag
  ] as [String: Any?]).compact()
}

private func debugAdminDeviceIdentifier() -> String? {
  guard
    AppEnvironment.current.environmentType != .production,
    AppEnvironment.current.mainBundle.isRelease == false
  else { return nil }

  return deviceIdentifier(uuid: UUID())
}
