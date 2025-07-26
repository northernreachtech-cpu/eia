import firebase from "firebase/compat/app";
import "firebase/compat/firestore";
import "firebase/compat/storage";

// Firebase configuration from environment variables
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

// Validate required environment variables
const requiredVars = [
  "VITE_FIREBASE_API_KEY",
  "VITE_FIREBASE_AUTH_DOMAIN",
  "VITE_FIREBASE_PROJECT_ID",
  "VITE_FIREBASE_STORAGE_BUCKET",
  "VITE_FIREBASE_MESSAGING_SENDER_ID",
  "VITE_FIREBASE_APP_ID",
];

const missingVars = requiredVars.filter((varName) => !import.meta.env[varName]);
if (missingVars.length > 0) {
  console.warn("Missing Firebase environment variables:", missingVars);
}

// Initialize Firebase
const app = firebase.initializeApp(firebaseConfig);
const db = app.firestore();
const storage = app.storage();

// Types
export interface ForumPost {
  id: string;
  communityId: string;
  authorId: string;
  authorName: string;
  content: string;
  timestamp: firebase.firestore.Timestamp;
  likes: string[];
  replies?: ForumPost[];
}

export interface CommunityResource {
  id: string;
  communityId: string;
  name: string;
  description: string;
  fileUrl: string;
  fileName: string;
  fileSize: number;
  uploaderId: string;
  uploaderName: string;
  timestamp: firebase.firestore.Timestamp;
  downloads: number;
  downloaders: string[];
}

export interface CommunityMember {
  userId: string;
  communityId: string;
  name: string;
  joinedAt: firebase.firestore.Timestamp;
  lastActive: firebase.firestore.Timestamp;
  contributionScore: number;
  role: "member" | "moderator" | "admin";
}

// Community Posts Service
export class CommunityPostsService {
  static async getPosts(communityId: string): Promise<ForumPost[]> {
    try {
      const querySnapshot = await db
        .collection("community_posts")
        .where("communityId", "==", communityId)
        .orderBy("timestamp", "desc")
        .get();

      const posts: ForumPost[] = [];

      querySnapshot.forEach((doc: any) => {
        posts.push({ id: doc.id, ...doc.data() } as ForumPost);
      });

      return posts;
    } catch (error) {
      console.error("Error getting posts:", error);
      return [];
    }
  }

  static async createPost(
    post: Omit<ForumPost, "id" | "timestamp">
  ): Promise<string> {
    try {
      const docRef = await db.collection("community_posts").add({
        ...post,
        timestamp: firebase.firestore.FieldValue.serverTimestamp(),
        likes: [],
      });
      return docRef.id;
    } catch (error) {
      console.error("Error creating post:", error);
      throw error;
    }
  }

  static async getReplies(postId: string): Promise<ForumPost[]> {
    try {
      const querySnapshot = await db
        .collection("community_posts")
        .where("parentPostId", "==", postId)
        .orderBy("timestamp", "asc")
        .get();

      const replies: ForumPost[] = [];

      querySnapshot.forEach((doc: any) => {
        replies.push({ id: doc.id, ...doc.data() } as ForumPost);
      });

      return replies;
    } catch (error) {
      console.error("Error getting replies:", error);
      return [];
    }
  }

  static async toggleLike(postId: string, userId: string): Promise<void> {
    try {
      const postRef = db.collection("community_posts").doc(postId);
      const postDoc = await postRef.get();

      if (!postDoc.exists) {
        throw new Error("Post not found");
      }

      const postData = postDoc.data();
      const likes = postData?.likes || [];
      const userLiked = likes.includes(userId);

      if (userLiked) {
        await postRef.update({
          likes: firebase.firestore.FieldValue.arrayRemove(userId),
        });
      } else {
        await postRef.update({
          likes: firebase.firestore.FieldValue.arrayUnion(userId),
        });
      }
    } catch (error) {
      console.error("Error toggling like:", error);
      throw error;
    }
  }

  static async deletePost(postId: string): Promise<void> {
    try {
      await db.collection("community_posts").doc(postId).delete();
    } catch (error) {
      console.error("Error deleting post:", error);
      throw error;
    }
  }

  static subscribeToPosts(
    communityId: string,
    callback: (posts: ForumPost[]) => void
  ): () => void {
    const q = db
      .collection("community_posts")
      .where("communityId", "==", communityId)
      .orderBy("timestamp", "desc");

    return q.onSnapshot((querySnapshot: any) => {
      const posts: ForumPost[] = [];
      querySnapshot.forEach((doc: any) => {
        posts.push({ id: doc.id, ...doc.data() } as ForumPost);
      });
      callback(posts);
    });
  }
}

// Community Resources Service
export class CommunityResourcesService {
  static async getResources(communityId: string): Promise<CommunityResource[]> {
    try {
      const querySnapshot = await db
        .collection("community_resources")
        .where("communityId", "==", communityId)
        .orderBy("timestamp", "desc")
        .get();

      const resources: CommunityResource[] = [];

      querySnapshot.forEach((doc: any) => {
        resources.push({ id: doc.id, ...doc.data() } as CommunityResource);
      });

      return resources;
    } catch (error) {
      console.error("Error getting resources:", error);
      return [];
    }
  }

  static async uploadResource(
    communityId: string,
    file: File,
    name: string,
    description: string,
    uploaderId: string,
    uploaderName: string
  ): Promise<string> {
    try {
      // Upload file to Firebase Storage
      const storageRef = storage.ref();
      const fileRef = storageRef.child(
        `community_resources/${communityId}/${Date.now()}_${file.name}`
      );
      const snapshot = await fileRef.put(file);
      const downloadURL = await snapshot.ref.getDownloadURL();

      // Save resource metadata to Firestore
      const docRef = await db.collection("community_resources").add({
        communityId,
        name,
        description,
        fileUrl: downloadURL,
        fileName: file.name,
        fileSize: file.size,
        uploaderId,
        uploaderName,
        timestamp: firebase.firestore.FieldValue.serverTimestamp(),
        downloads: 0,
        downloaders: [],
      });

      return docRef.id;
    } catch (error) {
      console.error("Error uploading resource:", error);
      throw error;
    }
  }

  static async trackDownload(
    resourceId: string,
    userId: string
  ): Promise<void> {
    try {
      const resourceRef = db.collection("community_resources").doc(resourceId);
      await resourceRef.update({
        downloads: firebase.firestore.FieldValue.increment(1),
        downloaders: firebase.firestore.FieldValue.arrayUnion(userId),
      });
    } catch (error) {
      console.error("Error tracking download:", error);
      throw error;
    }
  }

  static async deleteResource(resourceId: string): Promise<void> {
    try {
      const resourceDoc = await db
        .collection("community_resources")
        .doc(resourceId)
        .get();
      if (resourceDoc.exists) {
        const data = resourceDoc.data();
        if (data?.fileUrl) {
          // Delete from Storage
          const fileRef = storage.refFromURL(data.fileUrl);
          await fileRef.delete();
        }
        // Delete from Firestore
        await resourceDoc.ref.delete();
      }
    } catch (error) {
      console.error("Error deleting resource:", error);
      throw error;
    }
  }
}

// Community Members Service
export class CommunityMembersService {
  static async getMembers(communityId: string): Promise<CommunityMember[]> {
    try {
      const querySnapshot = await db
        .collection("community_members")
        .where("communityId", "==", communityId)
        .orderBy("joinedAt", "desc")
        .get();

      const members: CommunityMember[] = [];

      querySnapshot.forEach((doc: any) => {
        members.push({ ...doc.data() } as CommunityMember);
      });

      return members;
    } catch (error) {
      console.error("Error getting members:", error);
      return [];
    }
  }

  static async addMember(
    member: Omit<CommunityMember, "joinedAt" | "lastActive">
  ): Promise<void> {
    try {
      await db
        .collection("community_members")
        .doc(`${member.communityId}_${member.userId}`)
        .set({
          ...member,
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
          lastActive: firebase.firestore.FieldValue.serverTimestamp(),
        });
    } catch (error) {
      console.error("Error adding member:", error);
      throw error;
    }
  }

  static async updateMemberActivity(
    communityId: string,
    userId: string
  ): Promise<void> {
    try {
      await db
        .collection("community_members")
        .doc(`${communityId}_${userId}`)
        .update({
          lastActive: firebase.firestore.FieldValue.serverTimestamp(),
        });
    } catch (error) {
      console.error("Error updating member activity:", error);
      throw error;
    }
  }

  static async updateContributionScore(
    communityId: string,
    userId: string,
    score: number
  ): Promise<void> {
    try {
      await db
        .collection("community_members")
        .doc(`${communityId}_${userId}`)
        .update({
          contributionScore: firebase.firestore.FieldValue.increment(score),
        });
    } catch (error) {
      console.error("Error updating contribution score:", error);
      throw error;
    }
  }
}
