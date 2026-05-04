import java.security.MessageDigest;

PImage playerImg;
PImage enermyImg;

int gameState = 0;
long score = 0; // เปลี่ยนจาก int เป็น long เพื่อแก้ปัญหา Integer Overflow เมื่อคะแนนทะลุ 2 พันล้าน
long highestScore = 0; // ตัวแปรเก็บคะแนนสูงสุดตลอดกาล

String SECRET_SALT = "SpaceDefender2026!"; // รหัสลับสำหรับตรวจสอบไฟล์

// ฟังก์ชันสร้างรหัส Hash เพื่อเช็คว่าไฟล์ถูกแก้ไขมั้ย
String generateHash(String input) {
  try {
    MessageDigest md = MessageDigest.getInstance("SHA-256");
    byte[] hash = md.digest((input + SECRET_SALT).getBytes("UTF-8"));
    StringBuilder hexString = new StringBuilder();
    for (int i = 0; i < hash.length; i++) {
      String hex = Integer.toHexString(0xff & hash[i]);
      if(hex.length() == 1) hexString.append('0');
      hexString.append(hex);
    }
    return hexString.toString();
  } catch (Exception ex) {
    return "";
  }
}

Player player;
ArrayList<Enemy> enemies;
ArrayList<FireParticle> fireParticles;

// Score multiply
int consecutiveHits = 0;
int currentMultiplier = 1;

void setup() {
    size(600, 800); // w:600 h:800
    noCursor(); // <--- คำสั่งซ่อนเคอร์เซอร์เมาส์
    playerImg = loadImage("spaceship.png");
    enermyImg = loadImage("asteroid.png");
    
    // โหลดไฟล์ highscore.txt ถ้ามี
    String[] lines = loadStrings("highscore.txt");
    if (lines != null && lines.length >= 2) {
        try {
            long loadedScore = Long.parseLong(lines[0]);
            String loadedHash = lines[1];
            
            // ยืนยันความถูกต้อง ถ้าแฮชรหัสตรงกันแปลว่าไม่ได้แอบเปลี่ยนตัวเลข
            if (loadedHash.equals(generateHash(String.valueOf(loadedScore)))) {
                highestScore = loadedScore;
            } else {
                println("detected value was edited by someone. Reset High Score...");
                highestScore = 0;
            }
        } catch (Exception e) {
            highestScore = 0;
        }
    }
    
    resetGame();
}

void draw() {
    background(20,20,40); // เผื่อโหลดรูปไม่ติด

    if (gameState == 0) {
        drawStartScreen();
    } else if (gameState == 1) {
      playgame();
    } else if (gameState == 2) {
        drawGameOverScreen();
    }
}

void playgame() {
    player.update();
    player.display();

    if (random(1) < 0.07) {
    enemies.add(new Enemy());
    }

    for (int i = enemies.size() - 1; i >= 0; i--) {
        Enemy e = enemies.get(i);
        e.update();
        e.display();

        if (dist(e.x, e.y, player.x, player.y) < e.size) {
            gameState = 2;
            // เช็คว่าถ้าคะแนนรอบนี้ มากกว่าคะแนนสูงสุดที่เคยทำได้ ให้บันทึกสถิติใหม่
            if (score > highestScore) {
                highestScore = score;
                // สร้างรหัส Hash ป้องกันการแอบแก้ แล้วบันทึกไปพร้อมตัวเลขคะแนน
                String hash = generateHash(String.valueOf(highestScore));
                String[] saveLines = { String.valueOf(highestScore), hash };
                saveStrings("highscore.txt", saveLines);
            }
        }

        if (e.isOffScreen()) {
            enemies.remove(i);
            consecutiveHits++;
            updateMultiplier();
            score += (100 * currentMultiplier);
        }
    }

    drawMultiplierUI();
}

void resetGame() {
  player = new Player();
  enemies = new ArrayList<Enemy>();
  score = 0;
  consecutiveHits = 0;
  currentMultiplier = 1;
  fireParticles = new ArrayList<FireParticle>();
}

void drawGameOverScreen() {
  fill(255, 0, 0);
  textAlign(CENTER, CENTER);
  textSize(50);
  text("GAME OVER", width/2, height/2 - 50);
  fill(255);
  textSize(30);
  text("Final Score: " + formatScore(score), width/2, height/2 + 10);
  
  // โชว์คะแนนสูงสุด
  fill(255, 255, 0); // สีเหลืองทอง
  textSize(24);
  text("Highest Score: " + formatScore(highestScore), width/2, height/2 + 50);
  
  fill(255);
  textSize(20);
  text("Click to Restart", width/2, height/2 + 90);
}

void drawStartScreen() {
    fill(255);
    textAlign(CENTER,CENTER);
    textSize(60);
    text("SPACE DEFENDER", width/2, height/2 - 50);
    
    // โชว์คะแนนสูงสุดบนหน้าจอแรกด้วย
    fill(255, 255, 0);
    textSize(24);
    text("Highest Score: " + formatScore(highestScore), width/2, height/2);
    
    fill(255);
    textSize(20);
    text("Click any button to START", width/2, height/2 + 50);
}

void drawMultiplierUI() {
  // ข้อความคะแนนหลักปกติ
  fill(255);
  textAlign(LEFT, TOP);
  textSize(24);
  text("Score: " + formatScore(score), 10, 10);
  
  if (currentMultiplier > 1) {
    pushMatrix();
    translate(width/2, 50); // ตำแหน่งกึ่งกลางด้านบน
    
    // จำกัดความอลังการของเอฟเฟกต์ไฟและการเด้ง ไม่ให้รกเกินไปเมื่อตัวคูณพุ่งไปหลักร้อยหรือหลักพัน (ตันที่ระดับ 15)
    int effectLevel = min(currentMultiplier, 15);
    
    // 1. สร้างและการวาดเอฟเฟกต์ไฟลุก
    // ปล่อยเศษไฟตามความแรงของตัวคูณ
    for (int i = 0; i < effectLevel/2 + 1; i++) { 
      fireParticles.add(new FireParticle(0, 0, effectLevel));
    }
    
    for (int i = fireParticles.size() - 1; i >= 0; i--) {
      FireParticle p = fireParticles.get(i);
      p.update();
      p.display();
      if (p.isDead()) {
        fireParticles.remove(i);
      }
    }

    // 2. เอฟเฟกต์ตัวหนังสือเด้ง (Motion Text)
    // แกว่งแบบ Sine Wave ตามวินาทีและแกว่งแรงขึ้นตาม Multiplier
    float bounceTimer = frameCount * 0.2;
    float scaleFactor = 1.0 + (sin(bounceTimer) * 0.05 * effectLevel);
    scale(scaleFactor);
    
    // แอนิเมชั่นโยกซ้ายขวานิดๆ เมื่อตัวคูณเยอะ
    rotate(sin(frameCount * 0.1) * 0.01 * (effectLevel-1));

    // ตัวหนังสือเปลี่ยนสีตามระดับคูณ (ยิ่งมากยิ่งเข้าใกล้สีแดง/ม่วง)
    if (currentMultiplier >= 100) fill(255, 0, 255); // ม่วงสว่างเมื่อถึงหลักร้อย
    else if (currentMultiplier >= 10) fill(0, 255, 255); // ฟ้าสว่างเมื่อสุด
    else if (currentMultiplier >= 5) fill(255, 50, 50); // แดง
    else fill(255, 200, 0); // เหลืองทอง

    textAlign(CENTER, CENTER);
    textSize(40);
    text("x" + currentMultiplier, 0, 0); // โชว์ตัวคูณ
    
    fill(255, 200);
    textSize(16);
    text(consecutiveHits + " HITS COMBO!", 0, 30); // โชว์คอมโบต่อเนื่อง
    
    popMatrix();
  }
}

void updateMultiplier() {
  // เปลี่ยน baseMultiplier เป็น long ป้องกันการคูณทะลุลิมิต
  long baseMultiplier = 1 + (consecutiveHits / 10);
  
  if (consecutiveHits >= 100) {
    int powLevels = consecutiveHits / 100;
    
    for (int i = 0; i < powLevels; i++) {
        baseMultiplier = baseMultiplier * baseMultiplier;
        // ดักเอาไว้เลยว่าถ้าเกิน 1000 ให้หยุดคูณทันที! ป้องกันบั๊กค่าติดลบซ่อนเร้น
        if (baseMultiplier > 1000) {
            baseMultiplier = 1000;
            break; 
        }
    }
  }
  
  currentMultiplier = (int)baseMultiplier;
  
  if (currentMultiplier > 1000) {
    currentMultiplier = 1000;
  }
}

// ฟังก์ชันสำหรับแปลงตัวเลขคะแนนให้เป็นตัวย่อ (K, M, B, T, ...)
String formatScore(long v) {
    if (v >= 1000000000000000000L) return String.format("%.1f Qi", v / 1000000000000000000.0); // Quintillion
    if (v >= 1000000000000000L)    return String.format("%.1f Qa", v / 1000000000000000.0);    // Quadrillion
    if (v >= 1000000000000L)       return String.format("%.1f T", v / 1000000000000.0);       // Trillion (ล้านล้าน)
    if (v >= 1000000000L)          return String.format("%.1f B", v / 1000000000.0);          // Billion (พันล้าน)
    if (v >= 1000000L)             return String.format("%.1f M", v / 1000000.0);             // Million (ล้าน)
    if (v >= 10000L)               return String.format("%.1f k", v / 1000.0);                // หมื่นขึ้นไปให้โชว์ K
    return String.valueOf(v); // ถ้าน้อยกว่าหมื่น ให้โชว์เลขปกติ
}

void mousePressed() {
    if (gameState == 0) {
        gameState = 1;
    } else if (gameState == 1) {
        player.update();
        player.display();
    } else if (gameState == 2) {
        resetGame();
        gameState = 1;
    }
}

class Player {
    float x,y, size = 60;
    Player() { x = width/2; y = height - 60;}
    void update() {
        x = mouseX;
        if (x < size/2) x = size/2;
        if (x > width - size/2) x = width - size/2;
    }
    void display() {
        imageMode(CENTER);
        image(playerImg, x, y, size, size);
    }
}

class Enemy {
    float x,y, speed, size = random(30,60);
    Enemy () {
        x = random(size, width - size);
        y = -50;
        speed = random(6,10);
    }
    void update() {
        y += speed;
    }
    void display() {
        imageMode(CENTER);
        image(enermyImg, x, y, size, size);
    }
    boolean isOffScreen() {
        return y > height;
    }
}
class FireParticle {
  float x, y, vx, vy;
  float life = 255;
  float size;
  int colorType;
  
  FireParticle(float startX, float startY, int mult) {
    x = startX + random(40, 80); // กระจายฝุ่นไฟรอบข้อความ
    y = startY + random(0, 50);
    vx = random(-1, 1);
    vy = random(-2, -0.5) * (1 + mult * 0.2); // ไฟจะพุ่งแรงขึ้นตามตัวคูณ
    size = random(10, 15 + mult * 2); // ไฟดวงใหญ่ขึ้น
    colorType = mult;
  }
  
  void update() {
    x += vx;
    y += vy;
    life -= 15; // ไฟค่อยๆจางหาย (opacity ลดลง)
    size *= 0.95; // ขนาดหดเล็กลง
  }
  
  void display() {
    noStroke();
    // เปลี่ยนสีไฟ: ถ้าคูณน้อยเป็นเหลือง, ปานกลางแดง, พีคสุดเป็นประกายฟ้า
    if (colorType >= 10) fill(100, 200, 255, life); 
    else if (colorType >= 5) fill(255, random(50, 100), 0, life); 
    else fill(255, random(150, 255), 0, life); 
    
    ellipse(x, y, size, size);
  }
  
  boolean isDead() { return life <= 0; }
}
