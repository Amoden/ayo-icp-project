import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import Map "mo:base/HashMap";
import Hash "mo:base/Hash";

actor {
    type Proposal = {
        id : Nat;
        title : Text;
        description : Text;
        creator : Principal;
        startTime : Int;
        endTime : Int;
        options : [Text];
    };

    type Vote = {
        proposalId : Nat;
        voter : Principal;
        optionIndex : Nat;
        timestamp : Int;
    };

    var proposals = Buffer.Buffer<Proposal>(0);

    func natHash(n : Nat) : Hash.Hash {
        Text.hash(Nat.toText(n));
    };

    var votes = Map.HashMap<Nat, Buffer.Buffer<Vote>>(0, Nat.equal, natHash);

    public shared (msg) func createProposal(title : Text, description : Text, options : [Text], durationInHours : Nat) : async Nat {
        let proposalId = proposals.size();
        let now = Time.now();
        let newProposal : Proposal = {
            id = proposalId;
            title = title;
            description = description;
            creator = msg.caller;
            startTime = now;
            endTime = now + (durationInHours * 3600 * 1_000_000_000);
            options = options;
        };
        proposals.add(newProposal);
        votes.put(proposalId, Buffer.Buffer<Vote>(0));
        proposalId;
    };

    public shared (msg) func vote(proposalId : Nat, optionIndex : Nat) : async Bool {
        let proposal = proposals.get(proposalId);
        let now = Time.now();

        if (now < proposal.startTime or now > proposal.endTime) {
            return false;
        };

        if (optionIndex >= proposal.options.size()) {
            return false;
        };

        let newVote : Vote = {
            proposalId = proposalId;
            voter = msg.caller;
            optionIndex = optionIndex;
            timestamp = now;
        };

        switch (votes.get(proposalId)) {
            case null {
                let voteBuffer = Buffer.Buffer<Vote>(1);
                voteBuffer.add(newVote);
                votes.put(proposalId, voteBuffer);
            };
            case (?voteBuffer) {
                let existingVote = voteBuffer.vals().next();
                switch (existingVote) {
                    case null { voteBuffer.add(newVote) };
                    case (?v) { return false }; // User has already voted
                };
            };
        };
        true;
    };

    public query func getProposal(proposalId : Nat) : async ?Proposal {
        if (proposalId < proposals.size()) {
            ?proposals.get(proposalId);
        } else {
            null;
        };
    };

    public query func getVoteResults(proposalId : Nat) : async [(Text, Nat)] {
        let proposal = proposals.get(proposalId);
        let voteBuffer = votes.get(proposalId);

        switch (voteBuffer) {
            case null { [] };
            case (?buffer) {
                var results = Array.tabulateVar<Nat>(proposal.options.size(), func(_) { 0 });
                for (vote in buffer.vals()) {
                    results[vote.optionIndex] += 1;
                };
                Array.tabulate<(Text, Nat)>(proposal.options.size(), func(i) { (proposal.options[i], results[i]) });
            };
        };
    };

    public query func getAllProposals() : async [Proposal] {
        Buffer.toArray(proposals);
    };
};
