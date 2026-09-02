use grimoire_core::{TrustCatalog, TrustSummary, TrustUse};

fn traits<T: std::fmt::Debug + Clone + PartialEq + Eq>() {}
fn ordered<T: Ord>() {}

#[test]
fn adapter_trust_values_keep_the_public_trait_floor() {
    traits::<TrustCatalog>();
    traits::<TrustSummary>();
    traits::<TrustUse>();
    ordered::<TrustUse>();
}
