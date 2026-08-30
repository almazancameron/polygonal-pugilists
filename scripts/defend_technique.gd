class_name DefendTechnique
extends Technique

func execute(user: Combatant, target: Combatant) -> String:
    user.add_status(DefendingStatus.new())

    return "%s braces to defend." % user.familiar.familiar_name