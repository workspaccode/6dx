package api

import "sort"

// Group model — docs/design/groups-and-roles.md §4.
//
// A member has two roles in a group:
//   - group_role: administrative authority (lead, admin, member, guest);
//   - functional_role: their job, which grants the operational capabilities
//     and depends on the group type (software / hardware).
//
// Endpoints ask for a Capability, never for a role, so custom roles can be
// added later without touching the handlers.

// GroupType is software or hardware; it never changes after creation.
type GroupType string

const (
	GroupSoftware GroupType = "software"
	GroupHardware GroupType = "hardware"
)

// GroupRole is the administrative role inside a group.
type GroupRole string

const (
	GroupLead   GroupRole = "lead"
	GroupAdmin  GroupRole = "admin"
	GroupMember GroupRole = "member"
	GroupGuest  GroupRole = "guest"
)

func (r GroupRole) valid() bool {
	switch r {
	case GroupLead, GroupAdmin, GroupMember, GroupGuest:
		return true
	}
	return false
}

// IsManager: lead or admin.
func (r GroupRole) IsManager() bool { return r == GroupLead || r == GroupAdmin }

// Capability is one thing a member may do.
type Capability string

const (
	CapViewGroup      Capability = "group.view"
	CapManageGroup    Capability = "group.manage"   // rename, archive, settings
	CapDeleteGroup    Capability = "group.delete"   // + transfer the lead
	CapManageMembers  Capability = "members.manage" // invite, change roles, remove
	CapManageProjects Capability = "projects.manage"
	CapManageWorkflow Capability = "workflow.manage" // states and phases
	CapViewFinance    Capability = "finance.view"
	CapComment        Capability = "comments.write"

	// software
	CapEditTasks    Capability = "tasks.edit"
	CapEditOwnTasks Capability = "tasks.edit_own"
	CapPlanSprints  Capability = "sprints.plan"
	CapReviewPR     Capability = "pr.review"
	CapMergePR      Capability = "pr.merge"
	CapQAPass       Capability = "qa.pass"
	CapIntegrations Capability = "integrations.manage"
	CapClientDecide Capability = "client.decide"

	// hardware
	CapEditBOM       Capability = "bom.edit"
	CapReleaseBOM    Capability = "bom.release"
	CapSubmitECO     Capability = "eco.submit"
	CapSubmitECR     Capability = "ecr.submit" // request only (technician)
	CapApproveECO    Capability = "eco.approve"
	CapApproveECOPro Capability = "eco.approve_production"
	CapManageBuilds  Capability = "builds.manage"
	CapRecordTests   Capability = "tests.record"
	CapApproveTests  Capability = "tests.approve"
	CapGateDecision  Capability = "gate.decide"
	CapFirmwareLink  Capability = "firmware.link"
	CapManageVendors Capability = "vendors.manage"
	CapCreatePO      Capability = "po.create"
	CapRequestPO     Capability = "po.request"
	CapApprovePO     Capability = "po.approve"
	CapMoveInventory Capability = "inventory.move"
	CapViewPrices    Capability = "prices.view"
	CapManageCerts   Capability = "certs.manage" // certifications (FCC / CE / UL…)
	CapManageLab     Capability = "lab.manage"   // lab equipment; anyone testing books it
)

// functionalRoles lists the valid functional roles per group type, with the
// operational capabilities each one grants (the matrices in §4.5 / §4.6).
var functionalRoles = map[GroupType]map[string][]Capability{
	GroupSoftware: {
		"tech_lead": {CapEditTasks, CapPlanSprints, CapReviewPR, CapMergePR, CapQAPass,
			CapIntegrations, CapManageProjects, CapComment},
		"developer": {CapEditTasks, CapReviewPR, CapComment},
		"reviewer":  {CapEditOwnTasks, CapReviewPR, CapMergePR, CapComment},
		"qa":        {CapEditTasks, CapQAPass, CapComment},
		"designer":  {CapEditOwnTasks, CapComment},
		"devops":    {CapEditOwnTasks, CapMergePR, CapIntegrations, CapComment},
		"pm":        {CapEditTasks, CapPlanSprints, CapComment},
		"client":    {CapClientDecide, CapViewFinance},
	},
	GroupHardware: {
		"hw_lead": {CapEditTasks, CapEditBOM, CapReleaseBOM, CapSubmitECO, CapApproveECO,
			CapApproveECOPro, CapManageBuilds, CapRecordTests, CapApproveTests,
			CapGateDecision, CapFirmwareLink, CapManageProjects, CapViewPrices, CapManageCerts,
			CapManageLab, CapComment},
		"electrical": {CapEditTasks, CapEditBOM, CapSubmitECO, CapApproveECO, CapManageBuilds,
			CapRecordTests, CapFirmwareLink, CapViewPrices, CapComment},
		"mechanical": {CapEditTasks, CapEditBOM, CapSubmitECO, CapApproveECO, CapManageBuilds,
			CapRecordTests, CapViewPrices, CapComment},
		"firmware": {CapEditTasks, CapSubmitECO, CapApproveECO, CapRecordTests, CapFirmwareLink,
			CapReviewPR, CapMergePR, CapComment},
		"test": {CapEditTasks, CapSubmitECO, CapApproveECOPro, CapManageBuilds, CapRecordTests,
			CapApproveTests, CapManageCerts, CapManageLab, CapComment},
		"technician": {CapEditOwnTasks, CapSubmitECR, CapRecordTests, CapMoveInventory, CapComment},
		"manufacturing": {CapEditTasks, CapEditBOM, CapSubmitECO, CapApproveECOPro, CapManageBuilds,
			CapRecordTests, CapViewPrices, CapManageCerts, CapComment},
		"procurement": {CapSubmitECO, CapApproveECOPro, CapManageVendors, CapCreatePO,
			CapMoveInventory, CapViewPrices, CapComment},
		"client": {CapViewFinance},
	},
}

// defaultLeadRole is the functional role of whoever creates a group.
var defaultLeadRole = map[GroupType]string{
	GroupSoftware: "tech_lead",
	GroupHardware: "hw_lead",
}

func validGroupType(t GroupType) bool {
	_, ok := functionalRoles[t]
	return ok
}

func validFunctionalRole(t GroupType, role string) bool {
	_, ok := functionalRoles[t][role]
	return ok
}

// capabilitiesFor merges what the group role and the functional role grant.
//
// The lead holds everything; an admin manages the group but gets operational
// powers only from their functional role (separation of duties: an admin
// does not release a BOM or decide a gate by being admin). A guest is
// read-only plus whatever their (client) functional role allows.
func capabilitiesFor(t GroupType, groupRole GroupRole, functionalRole string) map[Capability]bool {
	caps := map[Capability]bool{CapViewGroup: true}
	for _, c := range functionalRoles[t][functionalRole] {
		caps[c] = true
	}
	if groupRole == GroupGuest {
		// A guest never edits, whatever functional role was stored. They may
		// comment on tasks: that is how a client asks the team a question.
		allowed := map[Capability]bool{CapViewGroup: true, CapClientDecide: true, CapViewFinance: true,
			CapComment: true}
		for c := range caps {
			if !allowed[c] {
				delete(caps, c)
			}
		}
		caps[CapComment] = true
		return caps
	}
	caps[CapComment] = true
	if groupRole.IsManager() {
		for _, c := range []Capability{CapManageGroup, CapManageMembers, CapManageProjects,
			CapManageWorkflow, CapViewFinance} {
			caps[c] = true
		}
		if t == GroupHardware {
			caps[CapManageLab] = true
			caps[CapManageVendors] = true
			caps[CapCreatePO] = true
			caps[CapApprovePO] = true
			caps[CapMoveInventory] = true
			caps[CapViewPrices] = true
		}
	}
	if groupRole == GroupLead {
		caps[CapDeleteGroup] = true
		for _, c := range functionalRoles[t][defaultLeadRole[t]] {
			caps[c] = true
		}
	}
	if functionalRole != "client" && caps[CapEditBOM] {
		caps[CapRequestPO] = true // engineers request, procurement orders
	}
	return caps
}

// sortedCaps is the JSON form: a stable, sorted list.
func sortedCaps(caps map[Capability]bool) []string {
	out := make([]string, 0, len(caps))
	for c, ok := range caps {
		if ok {
			out = append(out, string(c))
		}
	}
	sort.Strings(out)
	return out
}

// legacyToGroupRoles maps a workspace role to the default group's roles; the
// same mapping as migration 0003.
func legacyToGroupRoles(role Role) (GroupRole, string) {
	switch role {
	case RoleOwner:
		return GroupLead, "tech_lead"
	case RoleAdmin:
		return GroupAdmin, "tech_lead"
	case RoleReviewer:
		return GroupMember, "reviewer"
	case RoleViewer:
		return GroupGuest, "client"
	default:
		return GroupMember, "developer"
	}
}

// workspaceRoleFor is the workspace membership a group invite grants. The
// group role is what matters inside the group; the workspace role keeps the
// legacy endpoints consistent (a guest is a viewer everywhere).
func workspaceRoleFor(groupRole GroupRole) Role {
	if groupRole == GroupGuest {
		return RoleViewer
	}
	return RoleDeveloper
}
