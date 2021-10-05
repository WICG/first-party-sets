# UA Policy Proposal

First-Party Sets aims to define the notion of "first-party" as a technical construct that can be used by browsers in development of tracking protections in browsers. [The W3C Do Not Track (DNT) specification defines a ‘party'](https://www.w3.org/TR/tracking-compliance/#party) as having:

1.   Common owners and common controllers
2.  "A group identity that is easily discoverable by a user"

The DNT definition of ‘party' converge with the findings and recommendations of the 2012 Federal Trade Commission report titled "[Protecting Consumer Privacy in an Era of Rapid Change](https://www.ftc.gov/sites/default/files/documents/reports/federal-trade-commission-report-protecting-consumer-privacy-era-rapid-change-recommendations/120326privacyreport.pdf)". This report also recommends, for the sake of user transparency:

3.  "Privacy notices should be clearer, shorter, and more standardized to enable better comprehension and comparison of privacy practices."

We propose that First-Party Sets will utilize these three principles as the cornerstones of its policy, to ensure sets are transparent and set defined limits of data access:

+   Domains must have a common owner, and common controller.
+   Domains must share a common group identity that is easily discoverable by users.
+   Domains must share a common privacy policy that is surfaced to the user via UI treatment (e.g. on the website footer).

Alternatives Considered, and Discarded:

+   TLS Certificate approach: we considered a standard by which all domains in a First Party must be present on the same TLS certificate or produce EV certification to confirm organizational affiliation. We assessed this standard didn't make sense to impose, given the security implications associated with EV/SAN requirements. 
+   Common user journeys: we considered a First Party Set policy that included a standard stating that users must be able to easily journey between different entities and share sites within a set must share common experiences such that users would be able to determine that each site is related. We discarded this approach given the subjectivity around what a common user journey is, and because certain sites that are unrelated may share some common user journeys (e.g. a sign-in with Google flow or check-out path). 

# Responsibilities of the User Agent

We recommend that browsers supporting First-Party Sets work together to:

+   Come to rough consensus on a common set of principles for the UA Policy.
+   Periodically review, and refine policy requirements.
+   Implement a UI surface to educate users when the website they are visiting is part of a First-Party Set with other registrable domains; and link to the provided common privacy policy.
+   Ensure that the browser periodically fetches updates to sets. We recommend that the time period between updates fetched into the browser not exceed 30 days.
+   Periodically validate a well-known end point provided by each domain in the First-Party Set containing cryptographic proof the domain is associated with the common privacy policy.

# Responsibilities of the Site Author

+   Maintain accuracy in self declaration of common ownership and controllership of the domains listed in a First-Party Set formation request. 
    +   This means that changes in ownership/controllership must be followed up with a request for changes in the site's First-Party Set within _XX [to be determined]_ days.
+   Make domain affiliations easily discoverable to the user by providing cryptographic proof at a well-known endpoint concerning the association to the common privacy policy.
+   Use First-Party Sets as a mechanism to enable user journeys, and improved user experience across related domains. 
+   Where relevant, site authors may choose to form multiple, disjoint First-Party Sets. In other words, it is not required that all domains owned and controlled by an organization must be part of a single First-Party Set. We recommend that site authors strive to create sets consistent with user understanding and expectations.

# Responsibilities of Independent Enforcement Entity

For each element of the First Party Set policy, we propose an enforcement method. Below we suggest how each element is enforced and what role, if any, an independent enforcement entity might play as part of the enforcement effort.

1. In order to use the First-Party Sets feature, an organization would need to publicly declare that they own and control the sites listed in their proposed set via cryptographic proof provided at a well-known end point. That statement then becomes part of the privacy representations that the organization is making to users, similar to disclosures about how data is collected and used that organizations make in privacy policies. Misrepresentations about an entity's ownership/control of a site that lead to the collection of user data outside of the First Party Sets policy would be enforceable in the same way that misrepresentations or misleading statements in privacy policies are. Organizations could be held responsible for fraud or misrepresentation either in direct legal action from users or by regulators that enforce either privacy or consumer protection laws on behalf of users.
2. In order to meet the condition that domains must share a common group identity that is easily discoverable by users; browsers may provide a UI to surface group identity when the top-level site is part of a First-Party Set. The common privacy policy which is cryptographically verifiable via a well-known end point is sufficient to prove adherence to a First-Party Set and provide a link via the browser UI to that policy.

Additional roles of enforcement entity: 

+   Verifies that the requester of the set formation has control over the domains. This may be done by requiring that manifest files in a prescribed format be hosted at .well-known locations on each domain in the set in addition to the cryptographic proof provided at a well-known end point
+   Performs technical check to ensure all First Party Sets are mutually exclusive (i.e. a site cannot be in multiple sets) 
+   Conducts manual reviews/investigations of First Party Sets that have been flagged by civil society/research community 
