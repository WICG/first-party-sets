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
+   Domains must facilitate reasonable verification measures by user agents and independent enforcement entities.

Alternatives Considered, and Discarded:

+   TLS Certificate approach: we considered a standard by which all domains in a First Party must be present on the same TLS certificate or produce EV certification to confirm organizational affiliation. We assessed this standard didn't make sense to impose, given the security implications associated with EV/SAN requirements. 
+   Common user journeys: we considered a First Party Set policy that included a standard stating that users must be able to easily journey between different entities and share sites within a set must share common experiences such that users would be able to determine that each site is related. We discarded this approach given the subjectivity around what a common user journey is, and because certain sites that are unrelated may share some common user journeys (e.g. a sign-in with Google flow or check-out path). 

# Responsibilities of the User Agent

We recommend that browsers supporting First-Party Sets work together to:

+   Come to rough consensus on a common set of principles for the UA Policy.
+   Periodically review, and refine policy requirements.
+   Implement a UI surface to educate users when the website they are visiting is part of a First-Party Set with other registrable domains; and link to the provided common privacy policy.
+   Ensure that the browser periodically fetches updates to sets. We recommend that the time period between updates fetched into the browser not exceed 30 days.
+   [Optional] Provide guidance/mechanisms for users and civil society to report potentially invalid or policy-violating sets, for investigation and manual verification by an independent enforcement entity.

# Responsibilities of the Site Author

+   Maintain accuracy in self declaration of common ownership and controllership of the domains listed in a First-Party Set formation request. 
    +   This means that changes in ownership/controllership must be followed up with a request for changes in the site's First-Party Set within _XX [to be determined]_ days.
+   Make domain affiliations easily discoverable to the user. As a best practice, site authors should strive to make domain affiliations easily observable to the user, such as through common branding.
+   Use First-Party Sets as a mechanism to enable user journeys, and improved user experience across related domains.
+   Use site configuration and policies that allow for reasonable verification and enforcement. For example, terms of service must allow independent enforcement entities to make test or spamtrap accounts if needed to verify a common privacy policy.
+   Where relevant, site authors may choose to form multiple, disjoint First-Party Sets. In other words, it is not required that all domains owned and controlled by an organization must be part of a single First-Party Set. We recommend that site authors strive to create sets consistent with user understanding and expectations.

# Responsibilities of Independent Enforcement Entity

For each element of the First Party Set policy, we propose an enforcement method. Below we suggest how each element is enforced and what role, if any, an independent enforcement entity might play as part of the enforcement effort.

<table>
<thead>
<tr>
<th><strong>Policy </strong></th>
<th><strong>Enforcement Method </strong></th>
<th><strong>Role of independent enforcement entity </strong></th>
</tr>
</thead>
<tbody>
<tr>
<td>Common owner and controller</td>
<td>Annual self-declaration<sup>1</sup></td>
<td>Maintains publicly-viewable declaration system, tracks changes, performs random "spot checks" for conformance based on publicly available information </td>
</tr>
<tr>
<td>A group identity that is easily discoverable by a users </td>
<td>UI treatment (and co-branding in some cases)<sup>2</sup> </td>
<td>None (solely the browser's and site author's responsibility)</td>
</tr>
<tr>
<td>Common Privacy Policy </td>
<td>Technical checks<sup>3</sup> </td>
<td>Performs technical check to ensure Privacy Policy is the same across all sites in the same set<sup>4</sup></td>
</tr>
</tbody>
</table>

<sup>1</sup> In order to use the First-Party Sets feature, an organization would need to publicly declare that they own and control the sites listed in their proposed set. The declaration would be required to be made in a publicly viewable location, such as an issue tracker on GitHub. That statement then becomes part of the privacy representations that the organization is making to users, similar to disclosures about how data is collected and used that organizations make in privacy policies. Misrepresentations about an entity's ownership/control of a site that lead to the collection of user data outside of the First Party Sets policy would be enforceable in the same way that misrepresentations or misleading statements in privacy policies are. Organizations could be held responsible for fraud or misrepresentation either in direct legal action from users or by regulators that enforce either privacy or consumer protection laws on behalf of users.

<sup>2</sup> In order to meet the condition that domains must share a common group identity that is easily discoverable by users; browsers may provide UI to surface group identity when the top-level site is part of a First-Party Set. In addition, it is the site author's responsibility to ensure that at least one of the following is true: 

+   sites within the set share a single domain name (but different TLDs)
+   sites within the set share a prominently displayed common brand 
+   sites within the set are prominently co-branded 
+   sites within the set prominently disclose to users the parent company owner/operator (via a notice one click away from the home page, pop-up, or other method)

<sup>3</sup> Site authors must ensure that a hyperlink to the common group privacy policy is placed on the default page of each domain listed on their proposed set; such that an automated technical check can be used to verify its presence.

<sup>4</sup>When an independent enforcement entity discovers that one member of a First-Party Set is using user data in a manner inconsistent with the common Privacy Policy, it may consider the set as invalid, without waiting for further verification steps to discover whether or not other members of the set are also violating their own policy in the same way.

Additional roles of enforcement entity: 

+   Verifies that the requester of the set formation has control over the domains. This may be done by requiring that manifest files in a prescribed format be hosted at `.well-known` locations on each domain in the set.
+   Performs technical check to ensure all First Party Sets are mutually exclusive (i.e. a site cannot be in multiple sets) 
+   Conducts manual reviews/investigations of First Party Sets that have been flagged by civil society/research community 
